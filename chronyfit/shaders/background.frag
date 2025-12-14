#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

// -----------------------------------------------------------
// --- PARAMÈTRES ---
// -----------------------------------------------------------

// INTENSITÉ GLOBALE
const float uIntensity = 0.4; 

// VIGNETTAGE
const float uVignetteStrength = 0.9;

// CONFIGURATION POLLEN
const int POLLEN_COUNT = 32;      // Nombre réduit de particules
const float POLLEN_SPEED = 0.05;  // Vitesse globale lente
const float POLLEN_SIZE_BASE = 0.02; // Taille de base plus grosse
// -----------------------------------------------------------


// --- COULEURS ---
const vec3 BLUE = vec3(0.0, 0.3, 0.9);
const vec3 PINK = vec3(0.9, 0.1, 0.6);
const vec3 BLACK = vec3(0.0, 0.0, 0.05);

// --- FONCTIONS UTILITAIRES ---

mat2 rotate(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

// Hachage pour l'aléatoire
vec2 hash22(vec2 p) {
    p = fract(p * vec2(5.3983, 5.4427));
    p += dot(p.yx, p.xy + vec2(21.5351, 14.3137));
    return fract(vec2(p.x * p.y * 95.4337, p.x * p.y * 97.597));
}

// --- LOGIQUE DU SHADER ---

vec3 background_color(vec2 uv) {
    vec3 col = vec3(0.0);
    float y = sin(uv.x - 0.2) * 0.3 - 0.1;
    float m = uv.y - y;
    col += mix(BLUE, BLACK, smoothstep(0.0, 1.0, abs(m)));
    col += mix(PINK, BLACK, smoothstep(0.0, 1.0, abs(m - 0.8)));
    return col * 0.5;
}

float wave(vec2 uv, float offset) {
    float time = uTime;
    float x_offset = offset;
    float x_movement = time * 0.1;
    float amp = sin(offset + time * 0.2) * 0.3;
    float y = sin(uv.x + x_offset + x_movement) * amp;
    float m = uv.y - y;
    return 0.0175 / max(abs(m) + 0.01, 1e-3) + 0.01;
}

void main() {
    float time = uTime;
    float ratio = uSize.x / uSize.y;
    
    // UV centré pour le fond et les vagues (espace -1 à 1 corrigé ratio)
    vec2 uv = (2.0 * FlutterFragCoord().xy - uSize) / uSize.y;
    vec2 origUV = uv; // Pour le vignettage
    uv *= 0.8;
    uv.y *= -1.0; 

    vec3 col = vec3(0.0);
    vec3 b = background_color(uv);
    
    // --- NOUVEAU SYSTÈME DE POLLEN ---
    // On travaille en UV 0->1 pour gérer le bouclage (wrap) facilement
    vec2 pUV = FlutterFragCoord().xy / uSize.y; // On garde le ratio Y pour la forme ronde
    // Correction du X pour centrer la zone de génération
    pUV.x -= (uSize.x - uSize.y) / (2.0 * uSize.y); 

    vec3 pollenLayer = vec3(0.0);
    
    for(int i = 0; i < POLLEN_COUNT; i++) {
        float fi = float(i);
        // Graine aléatoire unique par particule
        vec2 seed = vec2(fi * 12.34, fi * 56.78);
        vec2 randValues = hash22(seed); // x = pos start, y = variation
        
        // Taille variable (Gros et petit)
        float size = POLLEN_SIZE_BASE + (randValues.y * 0.03);
        
        // Position initiale aléatoire
        vec2 pos = randValues * vec2(ratio * 2.0, 2.0) - vec2(ratio * 0.5, 0.5); // Large zone
        
        // --- MOUVEMENT ORGANIQUE ---
        // 1. Dérive constante vers le haut (Updraft)
        float updraft = (time * POLLEN_SPEED) * (0.5 + randValues.x); // Vitesse variable
        pos.y += updraft;
        
        // 2. Oscillation latérale (Vent doux)
        // Utilisation de seed.x pour que chaque particule ait sa propre phase
        float sway = sin(time * 0.5 + seed.x * 10.0) * 0.15; 
        pos.x += sway;
        
        // 3. Bouclage (Wrap around)
        // Si la particule sort en haut, elle revient en bas
        // On utilise fract() sur une base ajustée pour boucler sur l'espace visible
        pos.y = fract(pos.y * 0.5) * 2.0 - 0.5; // Boucle sur hauteur ~2.0
        pos.x = fract((pos.x + ratio) / (ratio * 2.0)) * (ratio * 2.0) - ratio;

        // --- DESSIN ---
        // Distance entre le pixel actuel et la particule
        // On corrige le ratio pour que le ratio d'écran n'écrase pas le pollen
        float dist = distance(uv, pos);
        
        // Cercle très doux (Pollen flou)
        float shape = smoothstep(size, size * 0.2, dist);
        
        // Variation d'opacité (scintillement très lent)
        float opacity = 0.3 + 0.2 * sin(time * 0.5 + randValues.y * 10.0);
        
        pollenLayer += shape * opacity;
    }
    
    // Ajout du pollen (teinté légèrement par la couleur de fond pour l'intégration)
    col += pollenLayer * mix(vec3(1.0), b, 0.2);
    // ---------------------------------
    
    // --- VAGUES (Inchangé) ---
    for (int i = 0; i < 6; ++i) {
        float fi = float(i);
        vec2 ruv;

        ruv = uv * rotate(0.4 * log(length(uv) + 1.0));
        col += b * wave(ruv + vec2(0.1 * fi + 2.0, -0.7), 1.5 + 0.2 * fi) * 0.2;

        ruv = uv * rotate(0.2 * log(length(uv) + 1.0));
        col += b * wave(ruv + vec2(0.1 * fi + 5.0, 0.0), 2.0 + 0.15 * fi);

        ruv = uv * rotate(-0.4 * log(length(uv) + 1.0));
        ruv.x *= -1.0;
        col += b * wave(ruv + vec2(0.1 * fi + 10.0, 0.5), 1.0 + 0.2 * fi) * 0.1;
    }
    
    // Intensité
    col *= uIntensity;

    // Vignettage
    float distFromCenter = length(origUV);
    float vignette = smoothstep(1.5, 0.5 - (uVignetteStrength * 0.4), distFromCenter);
    col *= vignette;

    fragColor = vec4(col, 1.0);
}