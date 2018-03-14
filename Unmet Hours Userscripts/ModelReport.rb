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
    file.puts "Zone,Air Loop,Number of Spaces,Cooling Thermostat Schedule,Heating Thermostat Schedule,Humidifying Setpoint Schedule,Dehumidifying Setpoint Schedule,Zone Multiplier,Cooling Design Method,Cooling Design SAT (F),Cooling Design Temperature Difference (R),Heating Design Method,Heating Design SAT (F),Heating Design Temperature Difference (R),DOAS,DOAS Low Temperature (F),DOAS High Temperature (F)"
    
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
    
    num_spaces = zone.spaces.size
    
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
    
    zone_sizing = zone.sizingZone
    cooling_design_method = zone_sizing.zoneCoolingDesignSupplyAirTemperatureInputMethod
    cooling_design_SAT = zone_sizing.zoneCoolingDesignSupplyAirTemperature
    cooling_design_SAT = OpenStudio.convert(cooling_design_SAT,"C","F").get
    cooling_design_SAT_diff = zone_sizing.zoneCoolingDesignSupplyAirTemperatureDifference
    cooling_design_SAT_diff = OpenStudio.convert(cooling_design_SAT_diff,"K","R").get
    heating_design_method = zone_sizing.zoneHeatingDesignSupplyAirTemperatureInputMethod
    heating_design_SAT = zone_sizing.zoneHeatingDesignSupplyAirTemperature
    heating_design_SAT = OpenStudio.convert(heating_design_SAT,"C","F").get
    heating_design_SAT_diff = zone_sizing.zoneHeatingDesignSupplyAirTemperatureDifference
    heating_design_SAT_diff = OpenStudio.convert(heating_design_SAT_diff,"K","R").get
    
    account_for_doas = zone_sizing.accountforDedicatedOutdoorAirSystem
    doas_low_temp = "<n/a>"
    doas_high_temp = "<n/a>"
    
    if account_for_doas
      if zone_sizing.isDedicatedOutdoorAirLowSetpointTemperatureforDesignAutosized
        doas_low_temp = "autosize"
      else
        doas_low_temp =  zone_sizing.dedicatedOutdoorAirLowSetpointTemperatureforDesign.get
        doas_low_temp = OpenStudio.convert(doas_low_temp,"C","F").get
      end
      
      if zone_sizing.isDedicatedOutdoorAirHighSetpointTemperatureforDesignAutosized
        doas_high_temp = "autosize"
      else
        doas_high_temp =  zone_sizing.dedicatedOutdoorAirHighSetpointTemperatureforDesign.get
        doas_high_temp = OpenStudio.convert(doas_high_temp,"C","F").get
      end
    end
    
    file.puts "#{zone_name},#{air_loop_name},#{num_spaces},#{cooling_schedule},#{heating_schedule},#{humidifying_schedule},#{dehumidifying_schedule},#{zone_multiplier},#{cooling_design_method},#{cooling_design_SAT},#{cooling_design_SAT_diff},#{heating_design_method},#{heating_design_SAT},#{heating_design_SAT_diff},#{account_for_doas},#{doas_low_temp},#{doas_high_temp}"
    
  end
  
  def writeAirLoopsToFile(file, model)
    file.puts "Air Loop Name,Schedule,Night Cycle,Load Sizing Type,OA System,Economizer,DCV,Heat Exchanger,Heat Recovery 100% Heating Effectiveness,Supply Fan,Return Fan,Relief Fan,Setpoint Type"
    
    air_loops = model.getAirLoopHVACs.sort {|x, y| x.name.to_s <=> y.name.to_s}
    air_loops.each do |air_loop|
      writeAirLoopToFile(file, model, air_loop)
    end 
    
    file.puts  
  end
  
  def writeAirLoopToFile(file, model, air_loop)
    air_loop_name  = air_loop.name.to_s
    
    air_loop_schedule = air_loop.availabilitySchedule.name.to_s
    air_loop_night_cycle = air_loop.nightCycleControlType
    
    air_loop_sizing = air_loop.sizingSystem
    air_loop_sizing_type = air_loop_sizing.typeofLoadtoSizeOn
    
    oa_system_name = "<n/a>"
    economizer_type = "<n/a>"
    dcv = "<n/a>"
    if not air_loop.airLoopHVACOutdoorAirSystem.empty?
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_system_name = oa_system.name.to_s
      oa_controller = oa_system.getControllerOutdoorAir
      economizer_type = oa_controller.getEconomizerControlType
      controller_mechanical_ventilation = oa_controller.controllerMechanicalVentilation
      dcv = controller_mechanical_ventilation.demandControlledVentilation
    end
    
    heat_exchanger_name = "<n/a>"
    heat_sensible_heating_effectiveness_100 = "<n/a>"
    heat_exchangers = model.getHeatExchangerAirToAirSensibleAndLatents
    heat_exchangers.each do |heat_exchanger|
      if not heat_exchanger.airLoopHVAC.empty?
        heat_exchanger_air_loop_name = heat_exchanger.airLoopHVAC.get.name.to_s
        if heat_exchanger_air_loop_name == air_loop_name
          heat_exchanger_name = heat_exchanger.name.to_s
          heat_sensible_heating_effectiveness_100 = heat_exchanger.sensibleEffectivenessat100HeatingAirFlow
        end
      end
    end
    
    supply_fan = air_loop.supplyFan
    supply_fan_name = supply_fan.get.name.to_s
    
    return_fan_name = "<n/a>"
    relief_fan_name = "<n/a>"
    if not air_loop.returnFan.empty?
      return_fan_name = air_loop.returnFan.get.name.to_s
    end
    if not air_loop.reliefFan.empty?
      relief_fan_name = air_loop.reliefFan.get.name.to_s
    end
    
    setpoint_manager_name = "<n/a>"    
    setpoint_managers = model.getSetpointManagers
    setpoint_managers.each do |setpoint_manager|
      if not setpoint_manager.airLoopHVAC.empty?
        setpoint_manager_air_loop_name = setpoint_manager.airLoopHVAC.get.name.to_s
        if setpoint_manager_air_loop_name == air_loop_name
          setpoint_manager_name = setpoint_manager.name.to_s
        end
      end
    end
    
    file.puts "#{air_loop_name},#{air_loop_schedule},#{air_loop_night_cycle},#{air_loop_sizing_type},#{oa_system_name},#{economizer_type},#{dcv},#{heat_exchanger_name},#{heat_sensible_heating_effectiveness_100},#{supply_fan_name},#{return_fan_name},#{relief_fan_name},#{setpoint_manager_name}"
  end
  
  def writeFansToFile(file, model)
    file.puts "Fan Name,Type,Schedule,Static Pressure (inH2O),Sizing (cfm),Fan Efficiency,Motor Efficiency"
    
    fans = model.getFanVariableVolumes.sort {|x, y| x.name.to_s <=> y.name.to_s}
    fans += model.getFanConstantVolumes.sort {|x, y| x.name.to_s <=> y.name.to_s}
    fans += model.getFanOnOffs.sort {|x, y| x.name.to_s <=> y.name.to_s}
    fans += model.getFanZoneExhausts.sort {|x, y| x.name.to_s <=> y.name.to_s}
    fans.each do |fan|
      writeFanToFile(file, fan)
    end 
    
    file.puts  
  end
  
  def writeFanToFile(file, fan)
    fan_name = fan.name.to_s
    
    if not fan.to_FanVariableVolume.empty?
      fan_type = "Variable Volume"
    elsif not fan.to_FanConstantVolume.empty?
      fan_type = "Constant Volume"
    elsif not fan.to_FanZoneExhaust.empty?
      fan_type = "Zone Exhaust"
    else # on off
      fan_type = "On Off"
    end
    
    fan_schedule = fan.availabilitySchedule.name.to_s    
    fan_static_pressure = fan.pressureRise
    fan_static_pressure = OpenStudio.convert(fan_static_pressure,"Pa","inH_{2}O").get
    
    if fan.isMaximumFlowRateAutosized 
      fan_max_flowrate = "autosize"
    else
      fan_max_flowrate = fan.maximumFlowRate.get
      fan_max_flowrate = OpenStudio.convert(fan_max_flowrate,"m^3/s","ft^3/min").get
    end
    
    fan_efficiency = fan.fanEfficiency
    fan_motor_efficiency = fan.motorEfficiency
    
    file.puts "#{fan_name},#{fan_type},#{fan_schedule},#{fan_static_pressure},#{fan_max_flowrate},#{fan_efficiency},#{fan_motor_efficiency}"
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
      writeAirLoopsToFile(file, model)
      writeFansToFile(file, model)
      writeConstructionsToFile(file, model)
    end
    
    return true
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
ModelReport.new.registerWithApplication