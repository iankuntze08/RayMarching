
#ifndef MESH_H
#define MESH_H

struct Mesh
{
    GLuint VAO;
    GLuint VBO;
    GLsizei vertexCount;
};

struct InstancedMesh2
{
    GLuint VAO;
    GLuint VBO;
    GLuint EBO;
    GLuint instanceVBO;

    GLsizei vertexCount;
};

struct Mesh2
{
    GLuint VAO;
    GLuint VBO;
    GLuint EBO;

    GLsizei vertexCount;
    GLsizei indexCount;
};

#endif
