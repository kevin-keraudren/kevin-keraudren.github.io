#!/bin/sh 
# The next line restarts using vtk \
exec vtk "$0" "$@"

#
# Written by Kevin Keraudren, 05/11/2010
# kevin.keraudren10@imperial.ac.uk
#

if { $argc != 1 } {
    puts "Usage: ./plyreader4bundler.tcl points009.ply"
    exit
}
puts "\nUsage:\n"

puts "\tKeyboard interaction:"
puts "\t\t's'\tto view in surface mode"
puts "\t\t'w'\tto view in wireframe mode"
puts "\t\t'e|q'\tto exit"
puts "\t\t'r'\tto reset camera"
puts "\t\t'3'\tfor 3D stereo toggle"
puts "\t\t'c|a'\tto toggle between camera and actor modes"
puts "\t\t'j|t'\tto toggle between joystick or trackball mode"
puts "\t\t'u'\tto get at VTK Interactor prompt"

puts "\n\tMouse interaction:"
puts "\t\tleft:\trotate"
puts "\t\tmiddle:\tpan"
puts "\t\tright:\tzoom"

set input_file [lindex $argv 0]

# VTK does not show points but vertices. But the files created by Bundler
# contain only points. Hence we need to turn all those points into vertices,
# without forgetting their color, so that we can visualize them.

# VTK does not like the "diffuse_", so Perl hack for colors
exec cat $input_file | perl -pe "s@diffuse_@@" > /tmp/ply4vtk.ply

set tmp_file "/tmp/ply4vtk.ply"

package require vtk
package require vtkinteraction

vtkPLYReader r
   r SetFileName  $tmp_file
   r Update

if { [[r GetOutput] GetNumberOfVerts] == 0
        && [[r GetOutput] GetNumberOfPolys] == 0 } {

    set poly [r GetOutput]

        # Create topology of point cloud. This is necessary!
        vtkCellArray vertices
        set nb_pts [[$poly GetPoints] GetNumberOfPoints]

        vertices InsertNextCell $nb_pts
        for {set i 0} {$i < $nb_pts} {incr i} {
            vertices InsertCellPoint $i
        }
        $poly SetVerts vertices

    vtkPolyDataMapper plyMapper
        plyMapper SetInput $poly

    vtkActor plyActor
        plyActor SetMapper plyMapper
        [plyActor GetProperty] SetRepresentationToPoints
        [plyActor GetProperty] SetPointSize 1

    # Callback for the Tk entry
    proc point_size {} {
        [plyActor GetProperty] SetPointSize [.point_size.entry get]
        renWin Render
    }
    toplevel .point_size
    wm title .point_size "Point Size"
    entry .point_size.entry
    .point_size.entry insert 0 {1}
    pack .point_size.entry
    bind .point_size.entry <Return> point_size
       
} else {
    vtkPolyDataMapper plyMapper
        plyMapper SetInputConnection [r GetOutputPort]

    vtkActor plyActor
        plyActor SetMapper plyMapper
}

# Create the RenderWindow, Renderer and Window Interactor
vtkRenderer ren1
vtkRenderWindow renWin
    renWin AddRenderer ren1
    
# Add the actors to the renderer, set the background and size
ren1 AddActor plyActor
#   ren1 SetBackground 1 1 1

set vtkw [vtkTkRenderWidget .ren \
        -width 600 \
        -height 600 \
        -rw renWin]
::vtk::bind_tk_render_widget $vtkw

pack $vtkw  -fill both -expand yes


bind . <Key-m> {
    if {[wm attributes . -fullscreen]} {
        wm attributes . -fullscreen 0
    } else {
        wm attributes . -fullscreen 1
    }
}

#[ren1 GetActiveCamera] Zoom 3.0

# save screenshot as png
proc screenshot {} {
        vtkWindowToImageFilter win2img
        win2img SetInput renWin 
        vtkPNGWriter png
        png SetInput [win2img GetOutput]       
        png SetFileName [.top.entry get]
        png Write
}

toplevel .top
wm title .top Screenshot
entry .top.entry
.top.entry insert 0 {capture.png}
pack .top.entry
bind .top.entry <Return> screenshot


