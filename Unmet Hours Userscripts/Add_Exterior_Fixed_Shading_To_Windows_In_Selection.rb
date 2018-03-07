########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2017, Alliance for Sustainable Energy, LLC. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
#  following conditions are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#  disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#  following disclaimer in the documentation and/or other materials provided with the distribution.
#
#  (3) Neither the name of the copyright holder nor the names of any contributors may be used to endorse or promote
#  products derived from this software without specific prior written permission from the respective party.
#
#  (4) Other than as required in clauses (1) and (2), distributions in any form of modifications or other derivative
#  works may not use the "OpenStudio" trademark, "OS", "os", or any other confusingly similar designation without
#  specific prior written permission from Alliance for Sustainable Energy, LLC.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR
#  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
#  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################################################################

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class AddExteriorFixedShadingToWindowsInSelection < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Add Exterior Fixed Shading to Windows in Selection"
  end
  
  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new

    depth = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("depth",false)
    depth.setDisplayName("Shading Depth (inches)")
    depth.setDefaultValue(12.0)
    result << depth
    
    vertical_offset = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("vertical_offset",false)
    vertical_offset.setDisplayName("Vertical Offset from Top of Window (inches)")
    vertical_offset.setDefaultValue(0.0)
    result << vertical_offset
    
    horizontal_offset = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("horizontal_offset",false)
    horizontal_offset.setDisplayName("Horizontal Offset from Wall (inches)")
    horizontal_offset.setDefaultValue(0.0)
    result << horizontal_offset
    
    pitch = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("pitch",false)
    pitch.setDisplayName("Pitch of Shades (-90 to 90 degrees)")
    pitch.setDefaultValue(0.0)
    result << pitch

    count = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("count",false)
    count.setDisplayName("Number of Fixed Shades")
    count.setDefaultValue(1)
    result << count
    
    separation_distance = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("separation_distance",false)
    separation_distance.setDisplayName("Distance Between Fixed Shades (inches)")
    separation_distance.setDefaultValue(8.0)
    result << separation_distance
    
    remove_existing_shading = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_existing_shading",false)
    remove_existing_shading.setDisplayName("Remove Existing Space Shading Groups")
    remove_existing_shading.setDefaultValue(false)
    result << remove_existing_shading
    
    return result
  end

  def adjustPitchPoint3d(point, pitch_angle)
    theta_radians = pitch_angle*(Math::PI/180)
    new_point_y = point.y - point.z * Math.sin(theta_radians)
    new_point_z = point.z * Math.cos(theta_radians)
    new_point = OpenStudio::Point3d.new(point.x,new_point_y,new_point_z)    
  end

  def addExteriorShading(model,surface,depth,vertical_offset,horizontal_offset,pitch,count,separation_distance)
    # if !(s.subSurfaceType == "FixedWindow" || s.subSurfaceType == "OperableWindow" || s.subSurfaceType == "GlassDoor")
      # return nil
    # end

    vertices = surface.vertices
    face_transform = OpenStudio::Transformation.alignFace(vertices)
    face_vertices = face_transform.inverse() * vertices
    
    xmin = 0
    xmax = 0
    ymin = 0
    ymax = 0
    
    face_vertices.each do |face_vertex|
      xmin = [xmin,face_vertex.x].min
      xmax = [xmax,face_vertex.x].max
      ymin = [ymin,face_vertex.y].min
      ymax = [ymax,face_vertex.y].max
    end

    
    shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
    shading_surface_group.setName("#{surface.name.to_s} Shading Surfaces")
    shading_surface_group.setShadedSubSurface(surface)
    shading_surface_group.setSpace(surface.space.get)
    shading_surface_group.setShadingSurfaceType("Space")
    
    for i in (1..count)
      overhang_vertices = []
      point_1 = OpenStudio::Point3d.new(xmax, ymax, 0)
      point_2 = OpenStudio::Point3d.new(xmin, ymax, 0)
      point_3 = OpenStudio::Point3d.new(xmin, ymax, depth)
      point_4 = OpenStudio::Point3d.new(xmax, ymax, depth)
      point_3 = adjustPitchPoint3d(point_3, pitch)
      point_4 = adjustPitchPoint3d(point_4, pitch)
      point_1 = OpenStudio::Point3d.new(point_1.x, point_1.y + vertical_offset - separation_distance*(i-1), point_1.z + horizontal_offset)
      point_2 = OpenStudio::Point3d.new(point_2.x, point_2.y + vertical_offset - separation_distance*(i-1), point_2.z + horizontal_offset)
      point_3 = OpenStudio::Point3d.new(point_3.x, point_3.y + vertical_offset - separation_distance*(i-1), point_3.z + horizontal_offset)
      point_4 = OpenStudio::Point3d.new(point_4.x, point_4.y + vertical_offset - separation_distance*(i-1), point_4.z + horizontal_offset)
      overhang_vertices << point_1
      overhang_vertices << point_2
      overhang_vertices << point_3
      overhang_vertices << point_4
      
      new_vertices = face_transform * overhang_vertices
      shading_surface = OpenStudio::Model::ShadingSurface.new(new_vertices,model)
      shading_surface.setName("#{surface.name.to_s} Shading Surface #{i}")
      shading_surface.setShadingSurfaceGroup(shading_surface_group)   
    end

    return shading_surface_group
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model,runner,user_arguments) # initializes runner for new script

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end
    
    depth = runner.getDoubleArgumentValue("depth",user_arguments)
    vertical_offset = runner.getDoubleArgumentValue("vertical_offset",user_arguments)
    horizontal_offset = runner.getDoubleArgumentValue("horizontal_offset",user_arguments)
    pitch = runner.getDoubleArgumentValue("pitch",user_arguments)
    # need to add logic to do vertical rotation to add vertical fins
    count = runner.getIntegerArgumentValue("count",user_arguments)
    separation_distance = runner.getDoubleArgumentValue("separation_distance",user_arguments)    
    remove_existing_shading = runner.getBoolArgumentValue("remove_existing_shading",user_arguments)
    
    if depth < 0
      runner.registerAsNotApplicable("Cannot make overhang with negative depth")
    end
    
    depth = OpenStudio.convert(depth,"in","m").get
    vertical_offset = OpenStudio.convert(vertical_offset,"in","m").get
    horizontal_offset = OpenStudio.convert(horizontal_offset,"in","m").get
    separation_distance = OpenStudio.convert(separation_distance,"in","m").get
    
    any_in_selection = false
    cleaned_space_names = []
    model.getSubSurfaces.each do |s|

      next if not runner.inSelection(s)
      
      any_in_selection = true

      next if not (s.subSurfaceType == "FixedWindow" || s.subSurfaceType == "OperableWindow" || s.subSurfaceType == "GlassDoor")
      
      # see if we need to clean this space's shading groups
      if remove_existing_shading
        surface = s.surface
        if not surface.empty?
          space = surface.get.space
          if not space.empty?
            space_name = space.get.name.get
            if not cleaned_space_names.include?(space_name)
              space.get.shadingSurfaceGroups.each do |shadingSurfaceGroup|
                runner.registerInfo("Removing " + shadingSurfaceGroup.briefDescription + ".")
                shadingSurfaceGroup.remove
              end
              
              # make sure not to clean the same space twice
              if cleaned_space_names.index(space_name) == nil
                cleaned_space_names << space_name
              end
            end
          end
        end
      end

      new_shading_surface_group = addExteriorShading(model,s,depth,vertical_offset,horizontal_offset,pitch,count,separation_distance)
      runner.registerInfo("Added shading surfaces " + new_shading_surface_group.briefDescription + " to " + s.briefDescription + ".")

    end

    if not any_in_selection
      runner.registerAsNotApplicable("No sub surfaces in the current selection. Please select sub surfaces, surfaces, or spaces to add exterior fixed shading.")
    end

    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
AddExteriorFixedShadingToWindowsInSelection.new.registerWithApplication
