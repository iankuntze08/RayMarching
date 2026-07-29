
#version 330 core

in vec3 ourColor;
layout(origin_upper_left, pixel_center_integer) in vec4 gl_FragCoord;

uniform vec2 windowSize;
uniform float time;
uniform vec4 camPos;
uniform vec4 camLook;

out vec4 fragColor;


struct Sphere
{
    vec3 pos;
    vec3 color;
    float radius;
};

struct Plane
{
    float yPos;
    vec3 color;
};

struct Torus
{
    vec3 pos;
    float radius; // ?
};

struct Scene
{
    Sphere sphere;
    Torus torus;
};

const vec3 skyColor = vec3(0.6, 0.61, 0.9);
const vec3 surfaceColor = vec3(0.4, 0.4, 0.4);
const vec3 lightSource = normalize(vec3(2, 1, 0.0));

vec3 cameraPos = vec3(camPos.x, camPos.y, camPos.z);

vec3 cameraForward = vec3(camLook.x, camLook.y, camLook.z);
vec3 cameraRight = normalize(cross(cameraForward, vec3(0.0, 1.0, 0.0)));
vec3 cameraUp = cross(cameraRight, cameraForward);

const int rayMaxSteps = 1000;
const float minDistTolerance = 0.001;
const float maxDistTolerance = 250.0;

float smax(float x, float y, float blend)
{
    return ((x + y) + sqrt(pow(x - y, 2) + blend)) / 2.0;
}

float smin(float x, float y, float blend)
{
    return ((x + y) - sqrt(pow(x - y, 2) + blend)) / 2.0;
}

float sdfSphere(vec3 pos, Sphere s)
{
    return length(pos - s.pos) - s.radius;
}

float sdfTorus(vec3 pos, vec2 t)
{
  vec2 q = vec2(length(pos.xz) - t.x, pos.y);
  return length(q) - t.y;
}

float sdCappedCylinder( vec3 p, float r, float h )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdSphere( vec3 p, float r )
{
  return length(p) - r;
}

float sdTorus(vec3 pos, vec2 t)
{
  vec2 q = vec2(length(pos.xz) - t.x, pos.y);
  return length(q) - t.y;
}

float sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
  vec2 d = vec2( length(p.xz)-ra+rb, abs(p.y) - h + rb );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float sdf(Scene s, vec3 pos)
{
    float sDist = sdfSphere(pos, s.sphere);
    float tDist = sdfTorus(pos, vec2(1.4, 0.2));

    // return min(pDist, sDist);
    float min = smin(tDist, sDist, 0.5);
    // min = min(tDist, min);

    return min;
}

float rayMarch(vec3 rayDir, Scene s)
{
    float distanceFromOrigin = 0.0;
    for (int i = 0; i < rayMaxSteps; i++)
    {
        vec3 pos = cameraPos + (rayDir * distanceFromOrigin);
        float distFromSphere = sdf(s, pos);
        if (distFromSphere < minDistTolerance)
            return distanceFromOrigin;
        distanceFromOrigin += distFromSphere;
        if (distanceFromOrigin > maxDistTolerance)
            break;
    }
    return -1.0;
}

struct Ray
{
    vec3 newPos;
    vec3 prevPos;
    vec3 newVelDir;
    vec3 prevVelDir;
    float dt;
};

float distortion(float schwarzschildRadius, float dist, float distort)
{
	return pow(schwarzschildRadius, distort) / pow(dist, distort);
}

// Inigo Quilez the goat
float opSmoothSubtraction(float d1, float d2, float k)
{
    float h = clamp(0.5 - 0.5 * (d1 + d2) / k, 0.0, 1.0);
    return mix(d1, -d2, h) + k * h * (1.0 - h);
}

float sdAccretionDisc(vec3 pos, float innerR, float outerR)
{
    return opSmoothSubtraction(sdRoundedCylinder(pos, outerR, 0.15, 0.05), sdSphere(pos, innerR), 0.15);
}

float fixedRayMarch(vec3 rayDir, Scene s)
{
    Ray r = Ray(cameraPos, cameraPos, normalize(rayDir), normalize(rayDir), 0.05);
    float distanceFromOrigin = 0.0;
    vec3 curPos = cameraPos;
    // vec3 unaffectedDir = vec3(0.0);

    float distortionValue = 0.85;
    float schwarzchildRadius = 0.01;

    float discInnerRadius = 1.1;
    float discOuterRadius = 3.0;

    for (int i = 0; i < rayMaxSteps; i++)
    {
        vec3 unaffectedDir = normalize(r.prevVelDir) * r.dt;
        vec3 dirToCenter = normalize(-r.prevPos) * r.dt;
        float lerp = distortion(schwarzchildRadius, length(r.newPos), distortionValue);
        r.newVelDir = normalize(mix(unaffectedDir, dirToCenter, lerp)) * r.dt;
        r.newPos = r.prevPos + r.newVelDir;
        if (length(r.newPos) < 1.0)
            return -2.0;
        float distFromSphere = sdAccretionDisc(r.newPos, discInnerRadius, discOuterRadius);
        r.prevPos = r.newPos;
        r.prevVelDir = r.newVelDir;

        unaffectedDir = normalize(r.prevVelDir) * r.dt;
        dirToCenter = normalize(-r.prevPos) * r.dt;
        lerp = distortion(schwarzchildRadius, length(r.newPos), distortionValue);
        r.newVelDir = normalize(mix(unaffectedDir, dirToCenter, lerp)) * r.dt;
        r.newPos = r.prevPos + r.newVelDir;
        if (length(r.newPos) < 1.0)
            return -2.0;
        distFromSphere = sdAccretionDisc(r.newPos, discInnerRadius, discOuterRadius);
        r.prevPos = r.newPos;
        r.prevVelDir = r.newVelDir;







        if (distFromSphere < minDistTolerance)
            return distanceFromOrigin;
        distanceFromOrigin += distFromSphere;
        if (distanceFromOrigin > maxDistTolerance)
            break;
    }
    return -1.0;
}

vec3 getNormal(vec3 pos, Scene s)
{
    vec2 e = vec2(0.001, 0.0); // epsilon, equivalent to "dx"
    return normalize(sdf(s, pos) - vec3(sdf(s, pos - vec3(e.x, e.y, e.y)), sdf(s, pos - vec3(e.y, e.x, e.y)), sdf(s, pos - vec3(e.y, e.y, e.x))));
}

float softShadows(Scene s, vec3 pos, vec3 rayDir)
{
    float res = 1.0;
    float t = minDistTolerance;

    for (int i = 0; i < 64; i++)
    {
        float h = sdf(s, pos + rayDir * t);

        if (h < 0.0001)
            return 0.0;

        res = min(res, 8.0 * h / t);

        t += clamp(h, 0.01, 0.2);

        if (t > maxDistTolerance)
            break;
    }

    return clamp(res, 0.0, 1.0);
}

float randomDetailUV(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 getUV()
{
    vec2 randomOffset = vec2(randomDetailUV(gl_FragCoord.xy), randomDetailUV(gl_FragCoord.xy + 1.0)) - 0.5;

    vec2 uv = (((gl_FragCoord.xy + randomOffset) / windowSize) * 2.0) - 1.0;
    uv.x *= windowSize.x / windowSize.y;
    uv.y *= -1.0;

    return uv;
}

void main()
{
    vec3 color = vec3(skyColor);

    Sphere s1 = Sphere(vec3(2.0, 4.0, -0.5), vec3(0.9, 0.1, 0.1), 1.0);
    Torus t1 = Torus(vec3(0.4, 2.0, 1.2), 1.0);
    Scene scene = Scene(s1, t1);

    vec2 uv = getUV();
    vec3 rayDir = normalize(cameraForward + (uv.x * cameraRight) + (uv.y * cameraUp));
    float march = fixedRayMarch(rayDir, scene);

    if (march >= 0.0)
    {
        // vec3 pos = cameraPos + (rayDir * march); // pos WILL be on the spheres
        // vec3 normal = getNormal(pos, scene);
        // float diffuse = max(dot(normal, lightSource), 0.0);
        // color = s1.color * diffuse;
        color = s1.color;
    }
    if (int(march) == -2)
    {
        color = vec3(0.0, 0.0, 0.0);
    }
    fragColor = vec4(color, 1.0);
}
