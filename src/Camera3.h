#ifndef CAMERA_3D
#define CAMERA_3D

#include <KHR\khrplatform.h>
#include <glad/glad.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glfw3.h>

#include <iostream>

class Camera3D
{
    public:
        glm::vec3 cameraPos;
        float speed;
        glm::vec3 cameraFront;
        glm::vec3 cameraUp;
        bool wireframe;
        int wireframeTimer;

        Camera3D(glm::vec3 camPos, float camSpeed)
        {
            this->cameraPos = camPos;
            this->speed = camSpeed;

            glm::vec3 cameraTarget = glm::vec3(0.0f);
            glm::vec3 cameraDirection = glm::normalize(cameraPos - cameraTarget);
            glm::vec3 up = glm::vec3(0.0f, 1.0f, 0.0f);
            glm::vec3 cameraRight = glm::normalize(glm::cross(up, cameraDirection));
            this->cameraUp = glm::cross(cameraDirection, cameraRight);
            this->cameraFront = glm::vec3(0.0f, 0.0f, -1.0f);
            this->wireframe = false;
            this->wireframeTimer = 0;
        }
        glm::mat4 updateView(glm::mat4& viewMatrix)
        {
            viewMatrix = glm::lookAt(cameraPos, cameraPos + cameraFront, cameraUp);
            return viewMatrix;
        }
        void doCameraMovement(GLFWwindow *window)
        {
            wireframeTimer += 1;
            if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
                glfwSetWindowShouldClose(window, 1);
            if (glfwGetKey(window, GLFW_KEY_F) == GLFW_PRESS)
                glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
            if (glfwGetKey(window, GLFW_KEY_G) == GLFW_PRESS)
                glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
            if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
                cameraPos += speed * cameraFront;
            if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
                cameraPos -= speed * cameraFront;
            if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
                cameraPos -= glm::normalize(glm::cross(cameraFront, cameraUp)) * speed;
            if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
                cameraPos += glm::normalize(glm::cross(cameraFront, cameraUp)) * speed;
            if (wireframeTimer < 5000)
                wireframeTimer = 0;
            if (glfwGetKey(window, GLFW_KEY_P) == GLFW_PRESS && wireframe == false)
            {
                glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
                wireframe = true;
                wireframeTimer = 0;
            }
            else if (glfwGetKey(window, GLFW_KEY_P) == GLFW_PRESS && wireframe == true)
            {
                glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
                wireframe = false;
                wireframeTimer = 0;
            }
        }
        void setCameraFront(glm::vec3 vec)
        {
            cameraFront = vec;
        }
};

#endif
