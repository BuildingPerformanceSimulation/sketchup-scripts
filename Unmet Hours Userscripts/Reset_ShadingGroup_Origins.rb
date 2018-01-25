class ResetShadingGroupOrigins < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Reset ShadingGroup Origins to Model Origin"
  end
  
  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new
    
    return result
  end

  def rotatePoint3D(point,degrees_rotation)
    radians = degrees_rotation*(Math::PI/180)
    cos = Math.cos(radians); sin = Math.sin(radians)
    new_point_x = point.x * cos - point.y * sin
    new_point_y = point.x * sin + point.y * cos
    new_point = OpenStudio::Point3d.new(new_point_x,new_point_y,point.z)  
    return new_point
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    model.getShadingSurfaceGroups.each do |group|

      x_shift = group.xOrigin
      y_shift = group.yOrigin
      z_shift = group.zOrigin
      relative_north = group.directionofRelativeNorth
      point_shift = OpenStudio::Vector3d.new(x_shift,y_shift,z_shift)
      group.resetDirectionofRelativeNorth
      group.resetXOrigin
      group.resetYOrigin
      group.resetZOrigin
      
      shading_surfaces = group.shadingSurfaces
      shading_surfaces.each do |surface|
        points = surface.vertices
        new_vertices = []
        points.each do |point|
          point = rotatePoint3D(point,-relative_north)
          point += point_shift
          new_vertices << point
        end
        surface.setVertices(new_vertices)
      end
    end
        
  end

end

ResetShadingGroupOrigins.new.registerWithApplication



