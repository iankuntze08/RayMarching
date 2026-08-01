
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
    float density;
};

float randomDetail3d(vec3 p)
{
    return fract(sin(dot(p, vec3(12.9898, 78.233, 34.5589))) * 43758.5453);
}

float accretionDensity(vec3 pos, float innerR, float outerR)
{
    float radius = length(pos.xz);
    float radial = smoothstep(innerR, innerR + 0.3, radius) * (1.0 - smoothstep(outerR - 0.5, outerR, radius));
    float height = abs(pos.y);
    float thickness = 0.03;
    float vertical = (exp(-(height * height) / (thickness * thickness))) * 5;

    float atmoVertical = (exp(-(height * height) / (thickness * thickness * 200.0))) * 0.1;
    float atmoRadial = smoothstep(innerR + 0.01, innerR + 0.3, radius) * (1.0 - smoothstep(outerR - 0.5, outerR + 0.5, radius));

    float middleVertical = (exp(-(height * height) / (thickness * thickness * 50.0))) * 0.2;

    return radial * vertical + atmoVertical * atmoRadial + middleVertical * atmoRadial;
}

vec3 sfloor3d(vec3 v)
{
    return v - (sin(2.0 * 3.1415 * v) / (2.0 * 3.1415));
}

// from https://www.shadertoy.com/view/3d3fWN
vec3 hash33(vec3 p3) {
	vec3 p = fract(p3 * vec3(.1031,.11369,.13787));
    p += dot(p, p.yxz+19.19);
    return -1.0 + 2.0 * fract(vec3((p.x + p.y)*p.z, (p.x+p.z)*p.y, (p.y+p.z)*p.x));
}
float worley(vec3 p, float scale){

    vec3 id = floor(p*scale);
    vec3 fd = fract(p*scale);

    float n = 0.;

    float minimalDist = 1.;


    for(float x = -1.; x <=1.; x++){
        for(float y = -1.; y <=1.; y++){
            for(float z = -1.; z <=1.; z++){

                vec3 coord = vec3(x,y,z);
                vec3 rId = hash33(mod(id+coord,scale))*0.5+0.5;

                vec3 r = coord + rId - fd;

                float d = dot(r,r);

                if(d < minimalDist){
                    minimalDist = d;
                }

            }//z
        }//y
    }//x

    return 1.0-minimalDist;
}

// from https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
float snoise(vec3 v){
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //  x0 = x0 - 0. + 0.0 * C
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
  i = mod(i, 289.0 );
  vec4 p = permute( permute( permute(
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 ))
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
  float n_ = 1.0/7.0; // N=7
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1),
                                dot(p2,x2), dot(p3,x3) ) );
}

float getTemperature(vec3 pos, float density)
{
    float d = length(pos);
    return smax(-pow(d, 1.05), 0.0, 0.5) * 20;
}

float randomDetailUV(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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
    float temperature = 0.0;
    vec4 res = vec4(0.0);

    for (int i = 0; i < rayMaxSteps; i++)
    {
        vec3 unaffectedDir = normalize(r.prevVelDir) * r.dt;
        vec3 dirToCenter = normalize(-r.prevPos) * r.dt;
        float lerp = distortion(schwarzchildRadius, length(r.newPos), distortionValue);
        r.newVelDir = normalize(mix(unaffectedDir, dirToCenter, lerp)) * r.dt;
        r.newPos = r.prevPos + r.newVelDir;
        if (length(r.newPos) < 0.015)
            return RayMarchResult(-2.0, r.newPos, r.newVelDir, rayDir, res, density);
        float distFromSphere = -sdAccretionDisc(r.newPos, discInnerRadius, discOuterRadius);
        r.prevPos = r.newPos;
        r.prevVelDir = r.newVelDir;

        vec2 polar = vec2(length(r.newPos.xz), atan(r.newPos.x / r.newPos.z));



        float density = accretionDensity(r.newPos, discInnerRadius, discOuterRadius);
        // density = 0.0;
        if (density > 0.0001)
        {
            vec3 warp =
                vec3(
                    snoise(r.newPos*2.0),
                    snoise(r.newPos*2.0+17.0),
                    snoise(r.newPos*2.0+42.0)
                );
            vec3 fdPos = vec3(r.newPos + warp * 0.3);
            density *= worley(fdPos, 10.0) * 2.0;
        }

        if (density > 0.001)
        {
            float stepSize = length(r.newVelDir);
            float alpha = 1.0 - exp(-density * stepSize * 5.0);
            vec4 col = vec4(vec3(0.6, 0.6, 0.95) * alpha * getTemperature(r.newPos, density), alpha);
            col *= worley(vec3(polar, randomDetailUV(polar) * 4.0), 4.0);
            res += col * (1.0 - res.w);
        }




        distanceFromOrigin -= distFromSphere;
        if (length(r.newPos) < eventHorizon)
            return RayMarchResult(-1.0, r.newPos, r.newVelDir, rayDir, res, density);
        if (distanceFromOrigin > maxDistTolerance)
            break;
    }
    return RayMarchResult(-distanceFromOrigin, r.newPos, r.newVelDir, rayDir, res, density);
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
    uv *= 250.0;
    vec2 id = floor(uv);
    vec2 f = fract(uv);

    float n = randomDetailUV(id);

    vec2 pos = vec2(
        fract(n * 123.45),
        fract(n * 678.90)
    );

    float d = length(f - pos);

    return exp(-d * 80.0) * step(0.95, n);
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
        float theta = atan(rmr.dir.z, rmr.dir.x);
        float phi = asin(clamp(rmr.dir.y, -1.0, 1.0));
        vec2 uv2 = vec2(theta / (2.0 * 3.1415) + 0.5, phi / 3.1415);
        color += vec3(stars(uv2));

        color += vec3(worley(rmr.dir, 0.8) * 0.2, 0.0, (worley(rmr.dir, 5.0) * 0.025) + (worley(rmr.dir, 2.0) * 0.1));
    }
    fragColor = vec4(color, 1.0);
}
