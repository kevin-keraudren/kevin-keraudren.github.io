#!/usr/bin/python

import csv, sys
from numpy import *

from glob import glob
from PIL import Image
import pprint

if len( sys.argv ) != 3:
    print "Usage: " + sys.argv[0] + " bundler.out img_dir/"
    sys.exit(1)

class camera(object):
    def __init__(self, f, k1, k2, R, T):
        self.focal = f
        self.k1 = k1
        self.k2 = k2
        self.R = R
        self.T = T
        self.center = dot(-transpose(R),T)
        self.direction = - R[2,:]
        if linalg.norm(self.R) == 0:
            self.BAD = True
        else:
            self.BAD = False

    def set_image( self, img_file ):
        self.image = img_file

    def image_corners(self):
        img = Image.open(self.image)
        R = self.R
        T = self.T
        (w, h) = img.size
        scaling = 0.01
        width = scaling * w
        height = scaling * h
        p1 = array( [-0.5*width, 0.5*height, 0])
        p1 = dot(linalg.inv(R), p1[:] - T[:])
        p2 = array( [0.5*width, 0.5*height, 0])
        p2 = dot(linalg.inv(R), p2[:] - T[:])
        p3 = array( [0.5*width, -0.5*height, 0])
        p3 = dot(linalg.inv(R), p3[:] - T[:])
        p4 = array( [-0.5*width, -0.5*height, 0])
        p4 = dot(linalg.inv(R), p4[:] - T[:])
        return [p1,p2,p3,p4]
    
    def __str__(self):
        pp = pprint.PrettyPrinter(indent=4)
        return pp.pformat(self.__dict__)

class point(object):
    def __init__(self, XYZ, color, views):
        self.xyz = XYZ
        self.color = color
        self.views = views
    
    def __str__(self):
        pp = pprint.PrettyPrinter(indent=4)
        return pp.pformat(self.__dict__)

    
def read( filename ):
    
    reader = csv.reader( open( sys.argv[1], 'rb'), delimiter=' ' )

    line_number = 0
    num_cameras = -1
    num_points = -1
    cameras = []
    points = []
    for row in reader:
        line_number += 1
        #print row
        if line_number == 1:
            continue
        row = filter( lambda x: x != '', row ) # remove empty strings

        #print row
        if line_number == 2:
            row = map( int, row )                  # convert strings to int
            num_cameras = row[0]
            num_points = row[1]
        elif line_number <= 2 + num_cameras * 5:
            row = map( float, row )                  # convert strings to int
            if ((line_number - 2) % 5) == 1:
                f = row[0]
                k1 = row[1]
                k2 = row[2]
            elif ((line_number - 2) % 5) == 2:
                R = zeros((3,3))
                R[0,:] = row
            elif ((line_number - 2) % 5) == 3:
                R[1,:] = row
            elif ((line_number - 2) % 5) == 4:
                R[2,:] = row
            else:
                T = array(row)
                cameras.append( camera(f, k1, k2, R.copy(), T.copy()) )
        else:
            if ((line_number - 2 - 5 * num_cameras) % 3) == 1:
                row = map( float, row )                  # convert strings to int
                XYZ = array(row)
            elif ((line_number - 2 - 5 * num_cameras) % 3) == 2:
                row = map( int, row )                  # convert strings to int
                color = row
            else:
                views = row
                points.append( point( XYZ.copy(), color, views))
    return (cameras, points)

(cameras, points) = read(sys.argv[1])

images = glob( sys.argv[2]+'/*.jpg')

print images

for c in range(len(cameras)):
    cameras[c].set_image(images[c])
    print cameras[c]

# VTK fun
import vtk

def camera_actor( camera):
    corners = camera.image_corners()
    vtk_points = vtk.vtkPoints()
    for p in corners:
        print p
        vtk_points.InsertNextPoint(p[0],p[1],p[2])
    
    polygons = vtk.vtkCellArray()
    polygon = vtk.vtkPolygon()
    polygon.GetPointIds().SetNumberOfIds(4) #make a quad
    polygon.GetPointIds().SetId(0, 0);
    polygon.GetPointIds().SetId(1, 1);
    polygon.GetPointIds().SetId(2, 2);
    polygon.GetPointIds().SetId(3, 3);

    polygons.InsertNextCell(polygon);

    quad = vtk.vtkPolyData()
    quad.SetPoints(vtk_points);
    quad.SetPolys(polygons);

    textureCoordinates = vtk.vtkFloatArray()
    textureCoordinates.SetNumberOfComponents(2)
    textureCoordinates.SetName("TextureCoordinates")
    textureCoordinates.InsertNextTuple2(1.0, 1.0)
    textureCoordinates.InsertNextTuple2(0.0, 1.0)
    textureCoordinates.InsertNextTuple2(0.0, 0.0)
    textureCoordinates.InsertNextTuple2(1.0, 0.0)
    
    quad.GetPointData().SetTCoords(textureCoordinates)

    print camera.image
    vtk_JPEGreader = vtk.vtkJPEGReader()
    vtk_JPEGreader.SetFileName( camera.image )
    vtk_JPEGreader.Update()

    flipFilter = vtk.vtkImageFlip()
    flipFilter.SetInputConnection(vtk_JPEGreader.GetOutputPort())
    flipFilter.Update()
  
    texture = vtk.vtkTexture()
    texture.SetInput(flipFilter.GetOutput())

    mapper = vtk.vtkPolyDataMapper()
    mapper.SetInput(quad)

    # actor
    actor = vtk.vtkActor()
    actor.SetMapper(mapper)
    actor.SetTexture(texture)

    return actor

def vtk_point_cloud(points):
    vtk_points = vtk.vtkPoints()
    vtk_verts = vtk.vtkCellArray()
    vtk_colors = vtk.vtkUnsignedCharArray()
    vtk_colors.SetNumberOfComponents(3) 
    vtk_colors.SetName( "Colors")
    cell = 0
    for point in points:
        p = point.xyz
        vtk_points.InsertNextPoint(p[0],p[1],p[2])
        vtk_verts.InsertNextCell(cell)
        vtk_colors.InsertNextTuple3( *point.color )
        cell += 1
    
    poly = vtk.vtkPolyData()
    poly.SetPoints(vtk_points)
    poly.SetVerts(vtk_verts)
    poly.GetPointData().SetScalars(vtk_colors)

    print poly

    mapper = vtk.vtkPolyDataMapper()
    mapper.SetInput(poly)

    actor = vtk.vtkActor()
    actor.SetMapper(mapper)
    actor.GetProperty().SetRepresentationToPoints
    actor.GetProperty().SetPointSize( 1)

    return actor

current_camera = 0

# create a rendering window and renderer
ren = vtk.vtkRenderer()
renWin = vtk.vtkRenderWindow()
renWin.AddRenderer(ren)
renWin.SetSize(600,600)
 
# create a renderwindowinteractor
iren = vtk.vtkRenderWindowInteractor()
iren.SetRenderWindow(renWin)


for c in cameras:
    if not c.BAD:
        break
    current_camera += 1
camera = cameras[current_camera]
actor = camera_actor(camera)

def decr_camera():
    global current_camera
    global actor
    global ren
    ren.RemoveActor(actor)
    current_camera = (current_camera - 1) % len(cameras)
    camera = cameras[current_camera]
    if camera.BAD:
        return decr_camera()
    else:
        actor = camera_actor(camera)
        ren.AddActor(actor)
        renWin.Render()
        return

def incr_camera():
    global current_camera
    global actor
    global ren
    ren.RemoveActor(actor)
    current_camera = (current_camera + 1) % len(cameras)
    camera = cameras[current_camera]
    if camera.BAD:
        return incr_camera()
    else:
        print camera.R
        actor = camera_actor(camera)
        ren.AddActor(actor)
        renWin.Render()
        return
    
def Keypress(obj, event):
    key = obj.GetKeySym()
    if key == "Left":
        print "left"
        decr_camera()
    elif key == "Right":
        print "right"
        incr_camera()        

        
point_cloud = vtk_point_cloud(points)

iren.AddObserver("KeyPressEvent", Keypress)

# assign actor to the renderer
ren.AddActor(actor)
ren.AddActor(point_cloud )

# enable user interface interactor
iren.Initialize()
renWin.Render()
iren.Start()
