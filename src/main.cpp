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
#include "Camera3.h"
#include "Quad.h"

void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    glViewport(0, 0, width, height);
}
void processInput(GLFWwindow* window);

const unsigned int SCR_WIDTH = 300;
const unsigned int SCR_HEIGHT = 300;

const int numCubeVertices = 108;

float yaw = 0.0;
float pitch = 0.0;
bool firstMouse = true;
float lastX = SCR_WIDTH / 2;
float lastY = SCR_HEIGHT / 2;

float dt = 0.01;
float dt2 = dt * dt;

Camera3D camera = Camera3D(glm::vec3(0.0f, 1.0f, 6.0f), 0.01f); // good pos for disk
// Camera3D camera = Camera3D(glm::vec3(0.0f, 0.0f, 3.4f), 0.005f); // good pos for just the object

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

void mouse_callback(GLFWwindow* window, double xpos, double ypos)
{
    if (firstMouse)
    {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }

    float xoffset = xpos - lastX;
    float yoffset = lastY - ypos;
    lastX = xpos;
    lastY = ypos;

    float sensitivity = 0.1f;
    xoffset *= sensitivity;
    yoffset *= sensitivity;

    yaw += xoffset;
    pitch += yoffset;

    if(pitch > 89.9f)
        pitch = 89.9f;
    if(pitch < -89.9f)
        pitch = -89.9f;

    glm::vec3 direction;
    direction.x = cos(glm::radians(yaw)) * cos(glm::radians(pitch));
    direction.y = sin(glm::radians(pitch));
    direction.z = sin(glm::radians(yaw)) * cos(glm::radians(pitch));
    camera.setCameraFront(glm::normalize(direction));
}

int main(int argc, char* argv[])
{
    const char* windowTitle = "OpenGL";
    GLFWwindow* window = initWindow(windowTitle);
    glfwSwapInterval(1); // ------------------ WARNING TURN OFF IF WANT HIGH FRAMERATES ------------------
    // Shader mainShader("shaders/vshader.glsl", "shaders/raymarching_fshader.glsl");
    Shader mainShader("shaders/vshader.glsl", "shaders/black_hole_fshader.glsl");
    UniformHandler uniformer(mainShader);

    uniformer.addWindowSize(window, "windowSize");
    float time = 0.0;
    GLint timeLoc = glGetUniformLocation(mainShader.ID, "time");
    GLint cameraPosLoc = glGetUniformLocation(mainShader.ID, "camPos");
    GLint cameraLookLoc = glGetUniformLocation(mainShader.ID, "camLook");

    glm::vec2 windowSize = glm::vec2(SCR_WIDTH, SCR_HEIGHT);

    FPSHandler fpsCounter = FPSHandler();

    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    glfwSetCursorPosCallback(window, mouse_callback);

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

        camera.doCameraMovement(window);

        uniformer.updateUniforms();
        uniformer.updateWindowSize(window);
        glUniform1f(timeLoc, time);
        glUniform4f(cameraPosLoc, camera.cameraPos.x, camera.cameraPos.y, camera.cameraPos.z, 0.0);
        glUniform4f(cameraLookLoc, camera.cameraFront.x, camera.cameraFront.y, camera.cameraFront.z, 0.0);

        glfwSwapBuffers(window);
        glfwPollEvents();

        // std::cout << "CAMERA POS : " << camera.cameraPos.x << " - " << camera.cameraPos.y << " - " << camera.cameraPos.z << "\n";

        fpsCounter.endTime = glfwGetTime();
    }

    return 0;
}
