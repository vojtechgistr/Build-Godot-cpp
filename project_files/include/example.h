#ifndef GDEXAMPLE_H         // include guard
#define GDEXAMPLE_H 

#include <Godot.hpp>        // Godot API
#include <Sprite.hpp>       // Sprite class

namespace godot
{

    //   class name : inheritance
    class GDExample : public Sprite
    {
        //       class name, inheritance
        GODOT_CLASS(GDExample, Sprite)

    private:
        float time_passed;      // variable to store time passed since last frame
        godot::Godot *gd;       // Pointer to Godot API


    public:
        //  Here you register all your methods you want to use in Godot Engine
        static void _register_methods();

        GDExample();                    // constructor

        ~GDExample();                   // destructor

        void _init();                   // called when the object is instantiated

        void _ready();                  // called when the node enters the scene tree

        void _process(float delta);     // called every frame

    protected:

    };

}

#endif
