#include <KHR/khrplatform.h>
#include <glad/glad.h>
#include <glfw3.h>
#include <glm/glm.hpp>
#define GLM_ENABLE_EXPERIMENTAL
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtx/perpendicular.hpp>

#include <iostream>

#include "..\shaders\Shader.h"
#include "UniformHandler.h"
#include "Constants.h"
#include "Mesh.h"
#include "Vertex.h"
#include "Quad.h"

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    glViewport(0, 0, width, height);
}
void processInput(GLFWwindow* window);

const unsigned int SCR_WIDTH = 600;
const unsigned int SCR_HEIGHT = 600;

const int numCubeVertices = 108;

float yaw = 0.0;
float pitch = 0.0;
bool firstMouse = true;
float lastX = SCR_WIDTH / 2;
float lastY = SCR_HEIGHT / 2;

float dt = 0.01;
float dt2 = dt * dt;

class FPSHandler
{
    public:
        float fps;
        float startTime;
        float endTime;
        int frames;

        FPSHandler();

        void fpsCheck()
        {
            if (endTime - startTime > 1.0)
            {
                fps = frames / (endTime - startTime);
                startTime = glfwGetTime();
                frames = 0;

                std::cout << "FPS: " << fps << "\r" << std::flush;
            }
        }

        void fpsCheck(GLFWwindow* window, const char* winTitle)
        {
            if (endTime - startTime > 1.0)
            {
                fps = frames / (endTime - startTime);
                startTime = glfwGetTime();
                frames = 0;

                std::cout << "FPS: " << fps << "\r" << std::flush;
                std::ostringstream ostr;
                ostr << winTitle << " - " << fps << " FPS";
                glfwSetWindowTitle(window, ostr.str().c_str());
            }
        }
        void printTime(float seconds)
        {
            if (endTime - startTime > 1.0)
                std::cout << "Seconds Elasped: " << floor(seconds) << " s\n";
        }
};

FPSHandler::FPSHandler()
{
    float fps = 0.0;
    float startTime = glfwGetTime();
    float endTime = 0.0;
    int frames = 0;
}

GLFWwindow* initWindow(const char* windowTitle)
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 4);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, true);
    GLFWwindow* window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, windowTitle, NULL, NULL);
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);
    return window;
}

int main(int argc, char* argv[])
{
    const char* windowTitle = "OpenGL";
    GLFWwindow* window = initWindow(windowTitle);
    Shader mainShader("shaders/vshader.glsl", "shaders/raymarching_fshader.glsl");
    UniformHandler uniformer(mainShader);

    uniformer.addWindowSize(window, "windowSize");
    float time = 0.0;
    GLint timeLoc = glGetUniformLocation(mainShader.ID, "time");

    glm::vec2 windowSize = glm::vec2(SCR_WIDTH, SCR_HEIGHT);

    FPSHandler fpsCounter = FPSHandler();

    Quad quad = Quad(glm::vec3(1.0, 0.0, 0.0));

    while (!glfwWindowShouldClose(window))
    {
        fpsCounter.frames += 1;
        // fpsCounter.fpsCheck();
        time += 1.0;
        fpsCounter.fpsCheck(window, windowTitle);

        glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        quad.draw(mainShader);

        uniformer.updateUniforms();
        uniformer.updateWindowSize(window);
        glUniform1f(timeLoc, time);

        glfwSwapBuffers(window);
        glfwPollEvents();

        fpsCounter.endTime = glfwGetTime();
    }

    return 0;
}
