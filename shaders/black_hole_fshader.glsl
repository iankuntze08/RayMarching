
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

const vec3 skyColor = vec3(0.01, 0.01, 0.01);
const vec3 surfaceColor = vec3(0.4, 0.4, 0.4);
const vec3 lightSource = normalize(vec3(2, 1, 0.0));

vec3 cameraPos = vec3(camPos.x, camPos.y, camPos.z);

vec3 cameraForward = vec3(camLook.x, camLook.y, camLook.z);
vec3 cameraRight = normalize(cross(cameraForward, vec3(0.0, 1.0, 0.0)));
vec3 cameraUp = cross(cameraRight, cameraForward);

const int rayMaxSteps = 2500;
const float minDistTolerance = 0.0005;
const float maxDistTolerance = 1000.0;

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
    return opSmoothSubtraction(sdRoundedCylinder(pos, outerR, 0.15, 0.015), sdSphere(pos, innerR), 0.15);
}

struct RayMarchResult
{
    float distFromCamera;
    vec3 pos;
    vec3 dir;
    vec3 oDir;
    vec4 color;
};

float accretionDensity(vec3 pos, float innerR, float outerR)
{
    float radius = length(pos.xz);
    float radial = smoothstep(innerR, innerR + 0.3, radius) * (1.0 - smoothstep(outerR - 0.5, outerR, radius));
    float height = abs(pos.y);
    float thickness = 0.03;
    float vertical = exp(-(height * height) / (thickness * thickness));

    return radial * vertical;
}

RayMarchResult fixedRayMarch(vec3 rayDir, Scene s)
{
    Ray r = Ray(cameraPos, cameraPos, normalize(rayDir), normalize(rayDir), 0.03);
    float distanceFromOrigin = 0.0;
    vec3 curPos = cameraPos;
    // vec3 unaffectedDir = vec3(0.0);

    float distortionValue = 1.75;
    float schwarzchildRadius = 0.1;

    float eventHorizon = 0.5;

    float discInnerRadius = 0.9;
    float discOuterRadius = 4.0;

    float density = 0.0;
    vec4 res = vec4(0.0);

    for (int i = 0; i < rayMaxSteps; i++)
    {
        vec3 unaffectedDir = normalize(r.prevVelDir) * r.dt;
        vec3 dirToCenter = normalize(-r.prevPos) * r.dt;
        float lerp = distortion(schwarzchildRadius, length(r.newPos), distortionValue);
        r.newVelDir = normalize(mix(unaffectedDir, dirToCenter, lerp)) * r.dt;
        r.newPos = r.prevPos + r.newVelDir;
        if (length(r.newPos) < 0.015)
            return RayMarchResult(-2.0, r.newPos, r.newVelDir, rayDir, res);
        float distFromSphere = -sdAccretionDisc(r.newPos, discInnerRadius, discOuterRadius);
        r.prevPos = r.newPos;
        r.prevVelDir = r.newVelDir;



        float density = accretionDensity(r.newPos, discInnerRadius, discOuterRadius);

        if (density > 0.001)
        {
            float stepSize = length(r.newVelDir);
            float alpha = 1.0 - exp(-density * stepSize * 5.0);
            vec4 col = vec4(vec3(1.0,0.4,0.1) * alpha, alpha);
            res += col * (1.0 - res.w);
        }




        distanceFromOrigin -= distFromSphere;
        if (length(r.newPos) < eventHorizon)
            return RayMarchResult(-1.0, r.newPos, r.newVelDir, rayDir, res);
        if (distanceFromOrigin > maxDistTolerance)
            break;
    }
    return RayMarchResult(-distanceFromOrigin, r.newPos, r.newVelDir, rayDir, res);
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
    // vec2 randomOffset = vec2(randomDetailUV(gl_FragCoord.xy), randomDetailUV(gl_FragCoord.xy + 1.0)) - 0.5;

    vec2 uv = (((gl_FragCoord.xy) / windowSize) * 2.0) - 1.0;
    uv.x *= windowSize.x / windowSize.y;
    uv.y *= -1.0;

    return uv;
}

// random stars
float stars(vec2 uv)
{
    vec2 id = floor(uv);
    vec2 f = fract(uv);

    float n = randomDetailUV(id);

    vec2 pos = vec2(
        fract(n * 123.4),
        fract(n * 456.7)
    );

    float d = length(f - pos);

    return exp(-d * 80.0) * step(0.95, n);
}

float temperature(float dist)
{
    return pow(dist, -1.2) + pow(dist, -9.0);
}

void main()
{
    vec3 color = vec3(skyColor);

    Sphere s1 = Sphere(vec3(2.0, 4.0, -0.5), vec3(0.8, 0.3, 0.1), 1.0);
    Torus t1 = Torus(vec3(0.4, 2.0, 1.2), 1.0);
    Scene scene = Scene(s1, t1);

    vec2 uv = getUV();
    vec3 rayDir = normalize(cameraForward + (uv.x * cameraRight) + (uv.y * cameraUp));
    RayMarchResult rmr = fixedRayMarch(rayDir, scene);
    float march = rmr.distFromCamera;
    rmr.dir = normalize(rmr.dir.x * cameraRight + rmr.dir.y * cameraUp + rmr.dir.z * cameraForward);
    float mag = length(rmr.pos);



    // if (march >= 0.0)
    // {
    //     // disc hit
    //     color = s1.color;
    // }
    // if (int(march) == -2)
    // {
    //     // the 'hole
    //     color = vec3(0.0, 0.0, 0.0);
    // }


    color = rmr.color.xyz;

    if (int(rmr.distFromCamera) != -1.0)
    {
        // stars
        float lon = atan(rmr.dir.z, rmr.dir.x);
        float lat = asin(clamp(rmr.oDir.y, -1.0, 1.0));

        vec2 uv2 = vec2( // dont ask
            lon / (2.0 * 3.1415) + 0.5,
            lat / 3.1415 + 0.5
        );
        uv2 *= 250.0;

        color += vec3(stars(uv2));
    }
    fragColor = vec4(color, 1.0);
}
