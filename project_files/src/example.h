#ifndef GDEXAMPLE_H
#define GDEXAMPLE_H

#include <Godot.hpp>
#include <Sprite.hpp>

namespace godot
{

    //   class name : inheritance
    class GDExample : public Sprite
    {
        GODOT_CLASS(GDExample, Sprite)

    private:
        float time_passed;
        godot::Godot *gd;

    public:
        static void _register_methods();

        GDExample();
        ~GDExample();

        void _init(); // our initializer called by Godot

        void _ready();

        void _process(float delta);

    protected:
    };

}

#endif
