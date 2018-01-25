# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class MakeSelectedChoiceSurfacesAdiabatic < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Make Selected Choice Surfaces Adiabatic and Assign a Construction"
  end
  
  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new
    
    surface_options = OpenStudio::StringVector.new
    surface_options << "Floor"
    surface_options << "Wall"
    surface_options << "RoofCeiling"    
    surface_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("surface_type",surface_options,true)
    surface_type.setDisplayName("Apply to surfaces of this surface type:")
    surface_type.setDefaultValue("Wall")
    result << surface_type

    boundary_options = OpenStudio::StringVector.new
    boundary_options << "Adiabatic"
    boundary_options << "Surface"
    boundary_options << "Outdoors"
    boundary_options << "Ground"
    boundary_condition = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("boundary_condition",boundary_options,true)
    boundary_condition.setDisplayName("Apply to surfaces with this boundary condition:")
    boundary_condition.setDefaultValue("Outdoors")
    result << boundary_condition
   
    construction_name = OpenStudio::Ruleset::makeChoiceArgumentOfWorkspaceObjects("construction_name", "OS_Construction".to_IddObjectType, model, false)
    construction_name.setDisplayName("(Optional) Pick a Construction For Adiabatic Surfaces")
    result << construction_name

    return result
  end

  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)      
    super(model, runner, user_arguments)

    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    surface_type = runner.getStringArgumentValue("surface_type",user_arguments)
    boundary_condition = runner.getStringArgumentValue("boundary_condition",user_arguments)

    selected_surfaces = []
    # get boundary condition
    model.getSurfaces.each do |surface|
      if runner.inSelection(surface)
        if surface.surfaceType == surface_type
          if surface.outsideBoundaryCondition == boundary_condition
            surface.setOutsideBoundaryCondition("Adiabatic")
            selected_surfaces << surface
          end
        end
      end
    end

    construction_name = runner.getStringArgumentValue("construction_name",user_arguments)
    return true if construction_name.empty?

    construction_uuid = OpenStudio::toUUID(construction_name)

    construction = nil
    c = model.getConstructionBase(construction_uuid)
    if c.empty?
      runner.registerError("Unable to locate construction " + construction_name + " in model.")
      return false
    end
    construction = c.get

    runner.registerInfo("Setting selected surfaces' construction to " + construction.briefDescription + ".")

    # if construction was picked, apply to surfaces
    selected_surfaces.each do |surface|
        surface.setConstruction(construction)
    end

    return true    
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
MakeSelectedChoiceSurfacesAdiabatic.new.registerWithApplication