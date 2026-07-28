#include <KHR\khrplatform.h>
#include <glad\glad.h>
#include <glfw3.h>
#include <glm/glm.hpp>
#define GLM_ENABLE_EXPERIMENTAL
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtx/perpendicular.hpp>

#include <iostream>
#include <fstream>
#include <vector>
#include <algorithm>
#include <random>
#include <array>

#include "..\shaders\Shader.h"

class UniformHandler
{
    public:
        struct unfloat
        {
            float value;
            GLint loc;
        };
        struct unmat4
        {
            glm::mat4 value;
            GLint loc;
        };
        struct unvec2
        {
            glm::vec2 value;
            GLint loc;
        };
        struct unwindow
        {
            GLFWwindow* window;
            GLint sizeLoc;
        };
        struct unint
        {
            int value;
            GLint loc;
        };

        std::vector<unfloat> floatList;
        std::vector<unmat4> mat4List;
        std::vector<unvec2> vec2List;
        std::vector<unint> intList;
        unwindow window;

        unmat4 viewMatrix;
        unmat4 projMatrix;
        unmat4 modelMatrix;
        unmat4 translationMatrix;

        UniformHandler(const Shader& shaderProgram) : shader(shaderProgram)
        {
        }

        void addfloat(const float& x, const char* name)
        {
            GLint uniformLoc = glGetUniformLocation(shader.ID, name);
            if (uniformLoc == -1)
                throw std::invalid_argument("Invalid uniform name");
            floatList.push_back(unfloat{x, uniformLoc});
        }
        void addmat4(const glm::mat4& x, const char* name)
        {
            GLint uniformLoc = glGetUniformLocation(shader.ID, name);
            if (uniformLoc == -1)
                throw std::invalid_argument("Invalid uniform name");
            mat4List.push_back(unmat4{x, uniformLoc});
        }
        GLint getUniformLoc(const char* name)
        {
            GLint uniformLoc = glGetUniformLocation(shader.ID, name);
            if (uniformLoc == -1)
                throw std::invalid_argument("Invalid uniform name");
            return uniformLoc;
        }
        void addvec2(const glm::vec2& x, const char* name)
        {
            GLint uniformLoc = glGetUniformLocation(shader.ID, name);
            if (uniformLoc == -1)
                throw std::invalid_argument("Invalid uniform name");
            vec2List.push_back(unvec2{x, uniformLoc});
        }
        void addWindowSize(GLFWwindow* window, const char* name)
        {
            GLint uniformLoc = glGetUniformLocation(shader.ID, name);
            if (uniformLoc == -1)
                throw std::invalid_argument("Invalid uniform name");
            this->window.sizeLoc = uniformLoc;
        }
        void add3DMatrices(glm::mat4& view, glm::mat4& proj, glm::mat4& model)
        {
            viewMatrix = {view, getUniformLoc("view")};
            projMatrix = {proj, getUniformLoc("proj")};
            modelMatrix = {model, getUniformLoc("model")};
        }
        void addInt(const int& x, const char* name)
        {
            GLint uniformLoc = glGetUniformLocation(shader.ID, name);
            if (uniformLoc == -1)
                throw std::invalid_argument("Invalid uniform name");
            intList.push_back(unint{x, uniformLoc});
        }


        void update3DMatrices(glm::mat4& view, glm::mat4& proj, glm::mat4& model)
        {
            viewMatrix.value = view;
            projMatrix.value = proj;
            modelMatrix.value = model;
        }
        void updateWindowSize(GLFWwindow* window)
        {
            int width, height;
            glfwGetWindowSize(window, &width, &height);
            // weird behavior if window.sizeLoc is undefined
            // the location will point to just random memory
            glUniform2f(this->window.sizeLoc, width, height);
        }
        void updateUniforms()
        {
            for (unmat4 x : mat4List)
                glUniformMatrix4fv(x.loc, 1, GL_FALSE, glm::value_ptr(x.value));
            for (unfloat x : floatList)
                glUniform1f(x.loc, x.value);
            for (unvec2 x : vec2List)
                glUniform2f(x.loc, x.value.x, x.value.y);
            for (unint x : intList)
                glUniform1i(x.loc, x.value);

            glUniformMatrix4fv(viewMatrix.loc, 1, GL_FALSE, glm::value_ptr(viewMatrix.value));
            glUniformMatrix4fv(projMatrix.loc, 1, GL_FALSE, glm::value_ptr(projMatrix.value));
            glUniformMatrix4fv(modelMatrix.loc, 1, GL_FALSE, glm::value_ptr(modelMatrix.value));
        }

    private:
        Shader shader;
};
