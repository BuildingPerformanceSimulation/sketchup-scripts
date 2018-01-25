######################################################################
#  Copyright (c) 2008-2016, Alliance for Sustainable Energy.  
#  All rights reserved.
#  
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

# Each user script is implemented within a class that derives from OpenStudio::Ruleset::UserScript
class ModelReport < OpenStudio::Ruleset::ModelUserScript

  # override name to return the name of your script
  def name
    return "Model Report"
  end
  
  # returns a vector of arguments, the runner will present these arguments to the user
  # then pass in the results on run
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new
    
    save_path = OpenStudio::Ruleset::OSArgument::makePathArgument("save_path", false, "csv",false)
    save_path.setDisplayName("Save Model Report As")
    save_path.setDefaultValue("ModelReport.csv")
    result << save_path
    
    return result
  end
  
  def round(x, d)
    result = (x * 10**d).round.to_f / 10**d
    return result
  end
  
  def ft2_per_m2
    return (10.7639)
  end
  
  def m2_per_ft2
    return (1.0/ft2_per_m2)
  end
  
  def writeBuildingToFile(file, model)
    file.puts "Building, Space Type, Floor Area (ft^2), Lighting Power Density (W/ft^2), Electric Equipment Density (W/ft^2), People Density (people/1000*ft^2)" 
    
    building = model.getBuilding
    
    building_name = building.name.to_s
    
    space_type = building.spaceType
    space_type_name = "<no space type>"
    if not space_type.empty?
      space_type_name = space_type.get.name.to_s
    end
    
    floor_area = round(ft2_per_m2*building.floorArea, 2)
    lpd = round(m2_per_ft2*building.lightingPowerPerFloorArea, 2)
    eed = round(m2_per_ft2*building.electricEquipmentPowerPerFloorArea, 2)
    pd = round(1000*m2_per_ft2*building.peoplePerFloorArea, 2)
    
    file.puts "#{building_name}, #{space_type_name}, #{floor_area}, #{lpd}, #{eed}, #{pd}" 
    file.puts
  end
  
  def writeSpaceTypesToFile(file, model)
    file.puts "Space Type, Floor Area (ft^2),Number of Spaces,Lighting Power Density (W/ft^2),Lighting Power (W),Electric Equipment Power Density (W/ft^2),Electric Equipment Power (W),People Density (people/1000*ft^2),People Density (ft^2/person),Outdoor Air Method, Outdoor Air Flow per Person (cfm/person),Outdoor Air Flow Rate per Floor Area (cfm/ft^2),Outdoor Air Flow Rate (cfm),Outdoor Air Flow Air Changes per Hour (1/h)" 
    
    space_types = model.getSpaceTypes.sort {|x, y| x.name.to_s <=> y.name.to_s}
    space_types.each do |space_type|
      spaces = space_type.spaces
      if not spaces.empty?
        writeSpaceTypeToFile(file, model, space_type.name.to_s, spaces)
      end
    end
    
    no_space_type_spaces = []
    spaces = model.getSpaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
    spaces.each {|space| no_space_type_spaces << space if space.spaceType.empty?}
    
    if not no_space_type_spaces.empty?
      writeSpaceTypeToFile(file, model, "<no space type>", no_space_type_spaces)
    end

    file.puts
  end
  
  
  def writeSpaceTypeToFile(file, model, space_type_name, spaces)
    
    floor_area = 0
    spaces.each do |space|
      floor_area += space.floorArea
    end

    num_spaces = spaces.size

    lpd = 0
    lp = 0
    eed = 0
    eep = 0
    pd = 0
    pd2 = 0
    oa_method = "<n/a>"
    oa_person = 0
    oa_area = 0
    oa_rate = 0
    oa_ach = 0
    space_type = model.getSpaceTypeByName(space_type_name)
    if not space_type.empty?
      space_type = space_type.get
      if not space_type.lightingPowerPerFloorArea.empty?
        lpd = space_type.lightingPowerPerFloorArea.get
        lp = round(floor_area*lpd, 2)
        lpd = round(m2_per_ft2*lpd, 2)
      end
      if not space_type.electricEquipmentPowerPerFloorArea.empty?
        eed = space_type.electricEquipmentPowerPerFloorArea.get
        eep = round(floor_area*eed, 2)
        eed = round(m2_per_ft2*eed, 2)
      end
      if not space_type.peoplePerFloorArea.empty?
        si_value = space_type.peoplePerFloorArea.get
        pd = round(1000*m2_per_ft2*si_value, 2)
        if (si_value > 0)
          pd2 = round(1/(m2_per_ft2*si_value),2)
        end
      end
      if not space_type.designSpecificationOutdoorAir.empty?
        design_oa = space_type.designSpecificationOutdoorAir.get
        oa_method = design_oa.outdoorAirMethod
        
        oa_person = round(OpenStudio.convert(design_oa.outdoorAirFlowperPerson,"m^3/s","cfm").get,2)
        oa_area = round(OpenStudio.convert(design_oa.outdoorAirFlowperFloorArea,"m/s","ft/min").get,2)
        oa_rate = round(OpenStudio.convert(design_oa.outdoorAirFlowRate,"m^3/s","cfm").get,2)
        oa_ach = round(design_oa.outdoorAirFlowAirChangesperHour,2)
      end
    end

    floor_area = round(ft2_per_m2*floor_area, 2)

    file.puts "#{space_type_name},#{floor_area},#{num_spaces},#{lpd},#{lp},#{eed},#{eep},#{pd},#{pd2},#{oa_method},#{oa_person},#{oa_area},#{oa_rate},#{oa_ach}" 
  end
  

  def writeBuildingStoriesToFile(file, model)
    file.puts "Building Story, Floor Area (ft^2), Number of Spaces" 
    
    stories = model.getBuildingStorys.sort {|x, y| x.name.to_s <=> y.name.to_s}
    stories.each do |story|
      spaces = story.spaces
      if not spaces.empty?
        writeBuildingStoryToFile(file, story.name.to_s, spaces)
      end
    end
    
    no_story_spaces = []
    spaces = model.getSpaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
    spaces.each {|space| no_story_spaces << space if space.buildingStory.empty?}
    
    if not no_story_spaces.empty?
      writeBuildingStoryToFile(file, "<no building story>", no_story_spaces)
    end

    file.puts
  end
  
  
  def writeBuildingStoryToFile(file, story_name, spaces)

    floor_area = 0
    spaces.each do |space|
      floor_area += space.floorArea
    end 
    floor_area = round(ft2_per_m2*floor_area, 2)

    num_spaces = spaces.size

    file.puts "#{story_name}, #{floor_area}, #{num_spaces}" 
  end
  
  
  def writeSpacesToFile(file, model)
  
    file.puts "Space,Space Type,Thermal Zone,Building Story,Floor Area (ft^2),Lighting Power Density (W/ft^2),Electric Equipment Density (W/ft^2),People Density (people/1000*ft^2)" 
    
    space_types = model.getSpaceTypes.sort {|x, y| x.name.to_s <=> y.name.to_s}
    space_types.each do |space_type|
      spaces = space_type.spaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
      spaces.each do |space|
        writeSpaceToFile(file, space_type.name.to_s, space)
      end
    end
    
    no_space_type_spaces = []
    spaces = model.getSpaces.sort {|x, y| x.name.to_s <=> y.name.to_s}
    spaces.each do |space| 
      if space.spaceType.empty?
        writeSpaceToFile(file, "<no space type>", space)
      end
    end
    
    file.puts
  end
  
  def writeSpaceToFile(file, space_type_name, space)

    space_name = space.name.to_s
        
    thermal_zone = space.thermalZone
    thermal_zone_name = "<no thermal zone>"
    if not thermal_zone.empty?
      thermal_zone_name = thermal_zone.get.name.to_s
    end

    building_story = space.buildingStory
    building_story_name = "<no building story>"
    if not building_story.empty?
      building_story_name = building_story.get.name.to_s
    end

    floor_area = round(ft2_per_m2*space.floorArea, 2)
    lpd = round(m2_per_ft2*space.lightingPowerPerFloorArea, 2)
    eed = round(m2_per_ft2*space.electricEquipmentPowerPerFloorArea, 2)
    pd = round(1000*m2_per_ft2*space.peoplePerFloorArea, 2)

    file.puts "#{space_name},#{space_type_name},#{thermal_zone_name},#{building_story_name},#{floor_area},#{lpd},#{eed},#{pd}" 
  end
  
  def writeThermalZonesToFile(file, model)
    file.puts "Zone,Air Loop,Cooling Thermostat Schedule,Heating Thermostat Schedule,Humidifying Setpoint Schedule,Dehumidifying Setpoint Schedule,Zone Multiplier,Number of Spaces" 
    
    zones = model.getThermalZones.sort {|x, y| x.name.to_s <=> y.name.to_s}
    zones.each do |zone|
      writeThermalZoneToFile(file, zone)
    end  

    file.puts
  end
  
  def writeThermalZoneToFile(file, zone)
  
    zone_name = zone.name.to_s
    
    air_loop_name = "<n/a>"
    air_loop_terminal = zone.airLoopHVACTerminal
    
    if not air_loop_terminal.empty?
      air_loop_terminal = air_loop_terminal.get
      air_loop_name = air_loop_terminal.loop.get.name.to_s
    end
    
    cooling_schedule = "<n/a>"
    heating_schedule = "<n/a>"
    humidifying_schedule = "<n/a>"
    dehumidifying_schedule = "<n/a>"
    
    zone_thermostat = zone.thermostatSetpointDualSetpoint
    zone_humidistat = zone.zoneControlHumidistat
    
    if not zone_thermostat.empty?
      zone_thermostat = zone_thermostat.get
      zone_cooling_schedule = zone_thermostat.coolingSetpointTemperatureSchedule
      zone_heating_schedule = zone_thermostat.heatingSetpointTemperatureSchedule
      
      if not zone_cooling_schedule.empty?        
        cooling_schedule = zone_cooling_schedule.get.name.to_s
      end
      
      if not zone_heating_schedule.empty?
        heating_schedule = zone_heating_schedule.get.name.to_s
      end
    end

    if not zone_humidistat.empty?
      zone_humidistat = zone_humidistat.get
      zone_humidifying_schedule = zone_humidistat.humidifyingRelativeHumiditySetpointSchedule
      zone_dehumidifying_schedule = zone_humidistat.dehumidifyingRelativeHumiditySetpointSchedule
      
      if not zone_humidifying_schedule.empty?        
        humidifying_schedule = zone_humidifying_schedule.get.name.to_s
      end
      
      if not zone_dehumidifying_schedule.empty?
        dehumidifying_schedule = zone_dehumidifying_schedule.get.name.to_s
      end
    end
    
    zone_multiplier = 1    
    if not zone.multiplier.nil?
      zone_multiplier = zone.multiplier
    end
    
    num_spaces = zone.spaces.size   
    
    file.puts "#{zone_name},#{air_loop_name},#{cooling_schedule},#{heating_schedule},#{humidifying_schedule},#{dehumidifying_schedule},#{zone_multiplier},#{num_spaces}"
  
  end

  def writeConstructionsToFile(file, model)
    file.puts "Construction Name,Area (ft^2),Type,Thermal Conductance (Btu/ft^2-h-R),R-value (ft^2*h*R/Btu),U-Value (Btu/ft^2-h-R)"
    
    constructions = model.getConstructionBases.sort {|x, y| x.name.to_s <=> y.name.to_s}
    constructions.each do |construction|
      writeConstructionToFile(file, construction)
    end  

    file.puts
  end

  def writeConstructionToFile(file, construction)
  
    construction_name = construction.name.to_s

    net_area = construction.getNetArea()
    
    if net_area > 0 #only record if used in building
      net_area = round(ft2_per_m2*net_area, 2)
      
      if construction.isFenestration()
        type = "fenestration"
      elsif construction.isGreenRoof()
        type = "green roof"
      elsif construction.isModelPartition()
        type = "partition"
      elsif construction.isOpaque()
        type = "opaque"
      else
        type = "<generic>"
      end
     
      thermal_conductance = "<n/a>"
      r_value_ip = "<n/a>"
      thermal_conductance_object = construction.thermalConductance
      if not thermal_conductance_object.empty?
        thermal_conductance = thermal_conductance_object.get
        thermal_conductance = OpenStudio.convert(thermal_conductance,"W/m^2*K","Btu/ft^2*h*R").get
        if thermal_conductance > 0
          r_value_ip = 1/thermal_conductance
          r_value_ip = round(r_value_ip, 3)
        end
        thermal_conductance = round(thermal_conductance, 3)
      end
      
      u_value = "<n/a>"    
      u_value_object = construction.uFactor
      if not u_value_object.empty?
        u_value = u_value_object.get
        u_value = OpenStudio.convert(u_value,"W/m^2*K","Btu/ft^2*h*R").get
        if u_value > 0
          r_value_ip = 1/u_value
          r_value_ip = round(r_value_ip, 3)
        end
        u_value = round(u_value, 3)
      end

      file.puts "#{construction_name},#{net_area},#{type},#{thermal_conductance},#{r_value_ip},#{u_value}"
    end
    
  end
  
  # override run to implement the functionality of your script
  # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
   
    if not runner.validateUserArguments(arguments(model),user_arguments)  
      return false
    end
    
    save_path = runner.getStringArgumentValue("save_path",user_arguments)
    
    # create file
    File.open(save_path, 'w') do |file|
      writeBuildingToFile(file, model)
      writeBuildingStoriesToFile(file, model)
      writeSpaceTypesToFile(file, model)
      writeSpacesToFile(file, model)
      writeThermalZonesToFile(file, model)
      writeConstructionsToFile(file,model)
    end
    
    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
ModelReport.new.registerWithApplication
