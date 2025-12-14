#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

// -----------------------------------------------------------
// --- PARAMÈTRES ---
// -----------------------------------------------------------

// --- VITESSE DE DÉFILEMENT (C'est ici !) ---
// Plus le chiffre est haut, plus ça va vite.
// 0.2 = Lent / 0.8 = Rapide / 1.5 = Très rapide
const float uSpeed = 0.5; 

// --- CONFIGURATION VISUELLE ---
const float rayCount = 24.0;       // Nombre de lignes (adapté pour portrait)
const float rayWidthBase = 0.015;  // Épaisseur des lignes
const float emission = 1.3;        // Intensité lumineuse globale

// -----------------------------------------------------------

// --- UTILITAIRES MATHÉMATIQUES ---

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453123);
}

// Évaluation d'une courbe de Bézier Cubique
vec2 cubicBezier(vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
    float s = 1.0 - t;
    float s2 = s * s;
    float t2 = t * t;
    return s2*s * p0 + 3.0*s2*t * p1 + 3.0*s*t2 * p2 + t*t*t * p3;
}

// Calcul approximatif de la distance point-courbe
// (Simplifié pour la performance mobile)
float distanceToBezier(vec2 point, vec2 p0, vec2 p1, vec2 p2, vec2 p3, out float closestT) {
    float minDist = 100.0;
    closestT = 0.0;
    
    // On échantillonne la courbe (moins d'échantillons pour mobile = +FPS)
    const int samples = 20; 
    for (int i = 0; i <= samples; i++) {
        float t = float(i) / float(samples);
        vec2 curvePoint = cubicBezier(p0, p1, p2, p3, t);
        float d = distance(point, curvePoint);
        if (d < minDist) {
            minDist = d;
            closestT = t;
        }
    }
    
    // Raffinement local
    float tMin = max(0.0, closestT - 0.05);
    float tMax = min(1.0, closestT + 0.05);
    
    for (int i = 0; i <= 5; i++) {
        float t = tMin + (tMax - tMin) * (float(i) / 5.0);
        vec2 curvePoint = cubicBezier(p0, p1, p2, p3, t);
        float d = distance(point, curvePoint);
        if (d < minDist) {
            minDist = d;
            closestT = t;
        }
    }
    return minDist;
}

void main() {
    // Normalisation des coordonnées
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    // Inversion Y (0 en bas, 1 en haut pour le point de fuite)
    uv.y = 1.0 - uv.y;

    // Couleurs définies (Respect de la demande)
    vec3 colPink = vec3(1.0, 0.0, 0.6);   // Magenta
    vec3 colCyan = vec3(0.0, 0.6, 1.0);   // Cyan
    vec3 colBlue = vec3(0.0, 0.0, 1.0);   // Bleu profond
    vec3 bgCol   = vec3(0.05, 0.0, 0.08); // Fond très sombre

    vec3 accColor = vec3(0.0); // Couleur accumulée
    
    // Paramètres géométriques
    float topWidth = 1.5;    // Point de fuite serré
    float bottomWidth = 1.0; // Largeur en bas de l'écran

    // Boucle principale des rayons
    for (float i = 0.0; i < 30.0; i += 1.0) {
        if (i >= rayCount) break;

        float rayIndex = i / (rayCount - 1.0); // 0.0 à 1.0
        
        // Définition de la courbe (Forme de "S" ou de guitare)
        float xStart = 0.5 + (rayIndex - 0.5) * topWidth; // Départ haut (serré)
        vec2 p3 = vec2(xStart, 1.0); // Point final (Haut écran)
        
        float xEnd = 0.5 + (rayIndex - 0.5) * bottomWidth; // Arrivée bas (large)
        vec2 p0 = vec2(xEnd, 0.0);   // Point départ (Bas écran)

        // Points de contrôle pour la courbure
        vec2 p1 = vec2(xEnd * 0.8 + 0.1, 0.3);
        vec2 p2 = vec2(xStart * 1.2 - 0.1, 0.7);

        // Calcul distance pixel -> courbe
        float t; // Position sur la ligne (0=bas, 1=haut)
        float dist = distanceToBezier(uv, p0, p1, p2, p3, t);

        // Largeur visuelle (plus fin au loin)
        float width = rayWidthBase * (1.0 - t * 0.6);
        
        // Glow de base du rayon
        float glow = exp(-dist / width) * 0.5; // Glow doux
        glow = smoothstep(0.0, 1.0, glow);

        // Choix de la couleur du rayon (aléatoire mais fixe par rayon)
        float rnd = hash(i * 54.3);
        vec3 rayColor = (rnd < 0.5) ? colPink : colCyan;
        if (rnd > 0.8) rayColor = colBlue;

        // --- IMPULSIONS (Les lumières qui voyagent) ---
        float pulses = 0.0;
        for (float p = 0.0; p < 2.0; p += 1.0) {
            // Vitesse contrôlée par uSpeed
            float phase = uTime * uSpeed + i * 0.3 + p * 0.6;
            float pulsePos = fract(phase); // Position 0->1
            
            // Distance du pixel à l'impulsion sur la ligne
            float dPulse = abs(t - pulsePos);
            
            // Forme de l'impulsion (tête brillante, traînée longue)
            float shape = 0.0;
            if (t < pulsePos) {
                // Traînée
                shape = exp(-dPulse * 8.0) * 0.5; 
            } else {
                // Tête (coupure nette devant)
                shape = exp(-dPulse * 50.0); 
            }
            
            // Atténuation aux extrémités de l'écran
            shape *= smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.8, t);
            
            pulses += shape;
        }

        // Combinaison : Glow de la ligne + Impulsions brillantes
        vec3 finalRayColor = rayColor * (glow * 0.2 + glow * pulses * 2.0);
        
        accColor += finalRayColor;
    }

    // Ajout du fond
    vec3 finalColor = bgCol + accColor * emission;

    // --- VIGNETTAGE (Demandé) ---
    // Vignette douce elliptique
    vec2 vUV = uv * (1.0 - uv.yx); // Astuce mathématique rapide
    float vig = vUV.x * vUV.y * 20.0; 
    vig = pow(vig, 0.25); 
    
    // Assombrissement supplémentaire en haut pour cacher le départ des lignes
    float topFade = smoothstep(0.95, 0.7, uv.y);
    
    finalColor *= vig * topFade;

    fragColor = vec4(finalColor, 1.0);
}