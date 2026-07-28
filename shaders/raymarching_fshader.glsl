
#version 330 core

in vec3 ourColor;
layout(origin_upper_left, pixel_center_integer) in vec4 gl_FragCoord;

uniform vec2 windowSize;
uniform float time;

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

struct Scene
{
    Plane plane;
    Sphere sphere;
};

const vec3 skyColor = vec3(0.6, 0.61, 0.9);
const vec3 surfaceColor = vec3(0.4, 0.4, 0.4);
const vec3 lightSource = normalize(vec3(2, 1, 0.0));

const vec3 lookAtPos = vec3(0.0, 0.5, 0.0);
vec3 cameraPos = vec3(3.0 * cos(time / 200.0), 2.0, 3.0 * sin(time / 200.0));

vec3 cameraForward = normalize(lookAtPos - cameraPos);
vec3 cameraRight = normalize(cross(cameraForward, vec3(0.0, 1.0, 0.0)));
vec3 cameraUp = cross(cameraRight, cameraForward);

const int rayMaxSteps = 100;
const float minDistTolerance = 0.007;
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

float sdf(Scene s, vec3 pos)
{
    float pDist = pos.y - s.plane.yPos;
    float sDist = sdfSphere(pos, s.sphere);

    // return min(pDist, sDist);
    return smin(pDist, sDist, 0.5);
};

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

        if (h < 0.001)
            return 0.0;

        res = min(res, 8.0 * h / t);

        t += clamp(h, 0.01, 0.2);

        if (t > maxDistTolerance)
            break;
    }

    return clamp(res, 0.0, 1.0);
}

vec2 getUV()
{
    vec2 uv = ((gl_FragCoord.xy / windowSize) * 2.0) - 1.0;
    uv.x *= windowSize.x / windowSize.y;
    uv.y *= -1.0;

    return uv;
}

void main()
{
    vec3 color = vec3(skyColor);

    Sphere s1 = Sphere(vec3(0.0, 0.5, 0.0), vec3(0.9, 0.1, 0.1), 1.0);
    Plane p1 = Plane(0.0, vec3(0.1, 0.6, 0.1));
    Scene scene = Scene(p1, s1);

    vec2 uv = getUV();
    vec3 rayDir = normalize(cameraForward + (uv.x * cameraRight) + (uv.y * cameraUp));
    float march = rayMarch(rayDir, scene);

    if (march >= 0.0)
    {
        vec3 pos = cameraPos + (rayDir * march); // pos WILL be on the sphere
        float sft = softShadows(scene, pos, lightSource);
        vec3 normal = getNormal(pos, scene);
        float diffuse = max(dot(normal, lightSource), 0.0);
        color = s1.color * diffuse * sft;
    }
    fragColor = vec4(color, 1.0);
}
