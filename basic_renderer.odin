package basic_renderer

import "core:fmt"
import "core:slice"

import X11 "vendor:x11/xlib"


main :: proc() {

    display := X11.OpenDisplay(nil)
    if display == nil {
        fmt.println("Unable to open X display")
        return
    }
    screen := X11.DefaultScreen(display)
    
    black: uint = X11.BlackPixel(display, screen) 
    white: uint = X11.WhitePixel(display, screen)
    
    IntVec4 :: distinct [4]u32
    root := X11.DefaultRootWindow(display)
    window := X11.CreateSimpleWindow(display, root, 0,0,800,600, 1, black, white)
    
    event : X11.XEvent
    eventmask := X11.EventMask{.KeyPress, .Exposure}
    X11.SelectInput(display, window, eventmask)
    
    X11.MapWindow(display, window)
    
    attributemask : X11.GCAttributeMask
    gc := X11.CreateGC(display, window, attributemask, nil)
    front_buffer := new([800][600]u32)
    back_buffer := new([800*600]u32)
    test_buffer := new([800*600]u32)
    
    for {

        for bool(X11.Pending(display)) {
            X11.NextEvent(display, &event)
        }

        
        if event.type == .Expose || event.type == .MotionNotify {
            depth := X11.DefaultDepth(display, screen)
            fmt.println(depth)
            width :u32 = 800
            height :u32 = 600
            front_image := X11.CreateImage(display, X11.DefaultVisual(display, screen), u32(depth), X11.ImageFormat.ZPixmap, 0, rawptr(front_buffer), u32(width), u32(height), 32, 0)
            back_image := X11.CreateImage(display, X11.DefaultVisual(display, screen), u32(depth), X11.ImageFormat.ZPixmap, 0, rawptr(back_buffer), u32(width), u32(height), 32, 0)
            test_image := X11.CreateImage(display, X11.DefaultVisual(display, screen), u32(depth), X11.ImageFormat.ZPixmap, 0, rawptr(test_buffer), u32(width), u32(height), 32, 0)

            mouse_root_x, mouse_root_y : i32
            mouse_win_x, mouse_win_y : i32
            keymask := X11.KeyMask.ControlMask
            root := X11.DefaultRootWindow(display)
            child : X11.Window
            X11.QueryPointer(display, window, &root, &child, &mouse_root_x, &mouse_root_y, &mouse_win_x, &mouse_win_y, &keymask)
            
            slice.zero(test_buffer[:])
            // fmt.println("HERE")
            
            // fmt.println("%d, %d", mouse_win_x, mouse_win_y)
            draw_rect_to_buffer(test_buffer[:], 600, 800, Rect{mouse_win_x, mouse_win_y, 100, 100}, u32(255 | 255<<8 | 123<<16 | 123<<24))
            
            shader(test_buffer[:], back_buffer[:], 600, 800)

            X11.PutImage(display, window, gc, back_image, 0, 0, 0, 0, width, height);
            
            
            test_image, back_image = back_image, test_image
        }
        // X11.DestroyImage(front_image);
        if event.type == .KeyPress {
            break
        }
    }
    X11.CloseDisplay(display)
}

Rect :: struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
}

RelativeRect :: struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
}

draw_rect :: proc(image: ^X11.XImage, rect: Rect, color: u32) {
    for i in rect.x ..< rect.x + i32(rect.h) {
        for j in rect.y ..< rect.y + i32(rect.w) {
            X11.PutPixel(image, i32(i), i32(j), uint(color))
        }
    }
}

draw_rect_to_buffer :: proc(image: []u32, screen_height: i32, screen_width: i32, rect: Rect, color: u32) {
    if screen_height < 0 || screen_width < 0 || rect.x < 0 || rect.y < 0 || rect.w < 0 || rect.h < 0 {
        return
    } 
    for i in rect.y ..< rect.y + rect.w {
        for j in rect.x ..< rect.x + rect.h {
            if rect.w + rect.x > screen_width || rect.h + rect.y > screen_height {
                continue
            }
            image[i*screen_width + j] = color
        }
    }
}

shader :: proc(buffer: []u32, new_buffer: []u32, screen_height: i32, screen_width: i32) {
    for i in 1 ..< screen_width {
        for j in 1 ..< screen_height {
            sumbuf : [9]u32
            if i-1 < 0 || i+1 >= screen_height || j-1 < 0 || j+1 > screen_width {
                continue
            }
            sumbuf[0] = buffer[(i-1)*screen_width + (j-1)]
            sumbuf[1] = buffer[(i  )*screen_width + (j-1)]
            sumbuf[2] = buffer[(i+1)*screen_width + (j-1)]
            sumbuf[3] = buffer[(i-1)*screen_width + (j  )]
            sumbuf[4] = buffer[(i  )*screen_width + (j  )]
            sumbuf[5] = buffer[(i+1)*screen_width + (j  )]
            sumbuf[6] = buffer[(i-1)*screen_width + (j+1)]
            sumbuf[7] = buffer[(i  )*screen_width + (j+1)]
            sumbuf[8] = buffer[(i+1)*screen_width + (j+1)]
            new_buffer[i*screen_width + j] = average(sumbuf[:])
        }
    }
}

average :: proc(slice: []u32) -> u32 {
    sum : u32 = 0
    for item in slice {
        sum += item
    }

    ave := sum/u32(len(slice))
    return ave

}