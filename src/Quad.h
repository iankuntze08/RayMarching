#include <glm/glm.hpp>

#include <array>

#include "../shaders/Shader.h"
#include "Mesh.h"
#include "Vertex.h"

#ifndef QUAD_H
#define QUAD_H

class Quad
{
private:
    Mesh2 mesh;
    std::array<unsigned int, 6> indices;
    glm::vec3 color;


public:
    std::array<Vertex, 4> vertices;

    Quad(glm::vec3 color, bool bufferStatus)
    {
        this->color = color;
        this->vertices = {
            Vertex{glm::vec3(-1.0f, 1.0f, 0.0f), color},
            Vertex{glm::vec3(-1.0f, -1.0f, 0.0f), color},
            Vertex{glm::vec3(1.0f, -1.0f, 0.0f), color},
            Vertex{glm::vec3(1.0f, 1.0f, 0.0f), color}
        };
        this->indices = {
            0, 1, 3, 1, 2, 3
        };
        if (bufferStatus == true)
            buffer();
    }
    Quad(glm::vec3 color)
    {
        this->color = color;
        this->vertices = {
            Vertex{glm::vec3(-1.0f, 1.0f, 0.0f), color},
            Vertex{glm::vec3(-1.0f, -1.0f, 0.0f), color},
            Vertex{glm::vec3(1.0f, -1.0f, 0.0f), color},
            Vertex{glm::vec3(1.0f, 1.0f, 0.0f), color}
        };
        this->indices = {
            0, 1, 3, 1, 2, 3
        };
        buffer();
    }

    void buffer()
    {
        glGenVertexArrays(1, &mesh.VAO);
        glGenBuffers(1, &mesh.VBO);
        glBindVertexArray(mesh.VAO);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.VBO);
        glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(Vertex), vertices.data(), GL_DYNAMIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, pos));
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, color));
        glEnableVertexAttribArray(1);

        glGenBuffers(1, &mesh.EBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.EBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), indices.data(), GL_DYNAMIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
        mesh.vertexCount = vertices.size();
        mesh.indexCount = indices.size();
    }

    void draw(Shader& shader)
    {
        shader.use();
        glBindBuffer(GL_ARRAY_BUFFER, mesh.VBO);
        glBindVertexArray(mesh.VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        // glBindVertexArray(0);
    }
};

#endif
