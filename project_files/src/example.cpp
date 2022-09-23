#include "example.h"

using namespace godot;

void GDExample::_register_methods()
{
    // Register functions
    register_method("_process", &GDExample::_process);
    register_method("_ready", &GDExample::_ready);
}

GDExample::GDExample()
{
}

GDExample::~GDExample()
{
    // add your cleanup here
}

void GDExample::_init()
{
    // initialize any variables here
    time_passed = 0.0;
}

// Call when script is ready
void GDExample::_ready()
{
    // add your code here
}

// Every frame
void GDExample::_process(float delta)
{
    time_passed += delta;

    Vector2 new_position = Vector2(10.0 + (10.0 * sin(time_passed * 2.0)), 10.0 + (10.0 * cos(time_passed * 1.5)));

    set_position(new_position);
}

