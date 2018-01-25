#start the measure
class AddDaylightSensorsToSelectedSpaces < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Add Daylight Sensors to Selected Spaces"
  end
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for setpoint
    setpoint = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("setpoint",true)
    setpoint.setDisplayName("Daylighting Setpoint (fc)")
    setpoint.setDefaultValue(45.0)
    args << setpoint

    #make an argument for control_type
    chs = OpenStudio::StringVector.new
    chs << "None"
    chs << "Continuous"
    chs << "Stepped"
    chs << "Continuous/Off"
    control_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("control_type",chs)
    control_type.setDisplayName("Daylighting Control Type")
    control_type.setDefaultValue("Continuous/Off")
    args << control_type

    #make an argument for min_power_fraction
    min_power_fraction = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_power_fraction",true)
    min_power_fraction.setDisplayName("Daylighting Minimum Input Power Fraction(min = 0 max = 0.6)")
    min_power_fraction.setDefaultValue(0.3)
    args << min_power_fraction

    #make an argument for min_light_fraction
    min_light_fraction = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_light_fraction",true)
    min_light_fraction.setDisplayName("Daylighting Minimum Light Output Fraction (min = 0 max = 0.6)")
    min_light_fraction.setDefaultValue(0.2)
    args << min_light_fraction

    #make an argument for height
    height = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("height",true)
    height.setDisplayName("Sensor Height (inches)")
    height.setDefaultValue(30.0)
    args << height

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    setpoint = runner.getDoubleArgumentValue("setpoint",user_arguments)
    control_type = runner.getStringArgumentValue("control_type",user_arguments)
    min_power_fraction = runner.getDoubleArgumentValue("min_power_fraction",user_arguments)
    min_light_fraction = runner.getDoubleArgumentValue("min_light_fraction",user_arguments)
    height = runner.getDoubleArgumentValue("height",user_arguments)


    #check the setpoint for reasonableness
    if setpoint < 0 or setpoint > 9999 #dfg need input on good value
      runner.registerError("A setpoint of #{setpoint} foot-candles is outside the measure limit.")
      return false
    elsif setpoint > 999
      runner.registerWarning("A setpoint of #{setpoint} foot-candles is abnormally high.") #dfg need input on good value
    end

    #check the min_power_fraction for reasonableness
    if min_power_fraction < 0.0 or min_power_fraction > 0.6
      runner.registerError("The requested minimum input power fraction of #{min_power_fraction} for continuous dimming control is outside the acceptable range of 0 to 0.6.")
      return false
    end

    #check the min_light_fraction for reasonableness
    if min_light_fraction < 0.0 or min_light_fraction > 0.6
      runner.registerError("The requested minimum light output fraction of #{min_light_fraction} for continuous dimming control is outside the acceptable range of 0 to 0.6.")
      return false
    end

    #check the height for reasonableness
    if height < -360 or height > 360 # neg ok because space origin may not be floor
      runner.registerError("A setpoint of #{height} inches is outside the measure limit.")
      return false
    elsif height > 72
      runner.registerWarning("A setpoint of #{height} inches is abnormally high.")
    elseif height < 0
      runner.registerWarning("Typically the sensor height should be a positive number, however if your space origin is above the floor then a negative sensor height may be approriate.")
    end

    #unit conversion from IP units to SI units
    setpoint_si = OpenStudio.convert(setpoint,'fc','lux').get
    height_si = OpenStudio.convert(height,'in','m').get

    #variable to tally the area to which the overall measure is applied
    area = 0
    #variables to aggregate the number of sensors installed and the area affected
    sensor_count = 0
    sensor_area = 0
    #array with subset of spaces
    spaces_selected_without_sensors = []
    affected_zones = []
    affected_zone_names = []
    #hash to hold sensor objects
    new_sensor_objects = {}

    num_spaces_selected = 0
    spaces_selected = []
    model.getSpaces.each do |space|
      next if not runner.inSelection(space)
      spaces_selected << space      
    end
    
    if spaces_selected.size == 0
      runner.registerAsNotApplicable("No spaces were selected.  Please select spaces to add daylight sensors.")
    end

    #reporting initial condition of model
    runner.registerInitialCondition("#{spaces_selected.size} spaces selected.")

    #test that there is no sensor already in the space, and that zone object doesn't already have sensors assigned.
    
    
    spaces_selected.each do |space|
      if space.daylightingControls.length == 0
        space_zone = space.thermalZone
        if not space_zone.empty?
          space_zone = space_zone.get
          if space_zone.primaryDaylightingControl.empty? and space_zone.secondaryDaylightingControl.empty?
            spaces_selected_without_sensors << space
          elsif
            runner.registerWarning("Thermal zone '#{space_zone.name}' which includes space '#{space.name}' already had a daylighting sensor. No sensor was added to space '#{space.name}'.")
          end
        else
          runner.registerWarning("Space '#{space.name}' is not associated with a thermal zone. It won't be part of the EnergyPlus simulation.")
        end
      else
        runner.registerWarning("Space '#{space.name}' already has a daylighting sensor. No sensor was added.")
      end
    end

    #loop through all spaces, and add a daylighting sensor with dimming to each
    space_count = 0
    spaces_selected_without_sensors.each do |space|
      space_count = space_count + 1
      area += space.floorArea

      # #eliminate spaces that don't have exterior natural lighting
      # has_ext_nat_light = false
      # space.surfaces.each do |surface|
        # next if not surface.outsideBoundaryCondition == "Outdoors"
        # surface.subSurfaces.each do |sub_surface|
          # next if sub_surface.subSurfaceType == "Door"
          # next if sub_surface.subSurfaceType == "OverheadDoor"
          # has_ext_nat_light = true
        # end
      # end
      # if has_ext_nat_light == false
        # runner.registerWarning("Space '#{space.name}' has no exterior natural lighting. No sensor will be added.")
       # next
      # end

      #find floors
      floors = []
      space.surfaces.each do |surface|
        next if not surface.surfaceType == "Floor"
        floors << surface
      end

      #this method only works for flat (non-inclined) floors
      boundingBox = OpenStudio::BoundingBox.new
      floors.each do |floor|
        boundingBox.addPoints(floor.vertices)
      end
      xmin = boundingBox.minX.get
      ymin = boundingBox.minY.get
      zmin = boundingBox.minZ.get
      xmax = boundingBox.maxX.get
      ymax = boundingBox.maxY.get

      #create a new sensor and put at the center of the space
      sensor = OpenStudio::Model::DaylightingControl.new(model)
      sensor.setName("#{space.name} daylighting control")
      x_pos = (xmin + xmax) / 2
      y_pos = (ymin + ymax) / 2
      z_pos = zmin + height_si #put it 1 meter above the floor
      new_point = OpenStudio::Point3d.new(x_pos, y_pos, z_pos)
      sensor.setPosition(new_point)
      sensor.setIlluminanceSetpoint(setpoint_si)
      sensor.setLightingControlType(control_type)
      sensor.setMinimumInputPowerFractionforContinuousDimmingControl(min_power_fraction)
      sensor.setMinimumLightOutputFractionforContinuousDimmingControl(min_light_fraction)
      sensor.setSpace(space)

      #push unique zones to array for use later in measure
      temp_zone = space.thermalZone.get
      if affected_zone_names.include?(temp_zone.name.to_s) == false
        affected_zones << temp_zone
        affected_zone_names << temp_zone.name.to_s
      end

      #push sensor object into hash with space name
      new_sensor_objects[space.name.to_s] = sensor

      #add floor area to the daylighting area tally
      sensor_area += space.floorArea

      #add to sensor count for reporting
      sensor_count += 1

    end #end spaces_selected_without_sensors.each do

    #loop through thermal Zones for spaces with daylighting controls added
    affected_zones.each do |zone|
      zone_spaces = zone.spaces
      zone_spaces_with_new_sensors = []
      zone_spaces.each do |zone_space|
        if not zone_space.daylightingControls.empty?
          zone_spaces_with_new_sensors << zone_space
        end
      end

      if not zone_spaces_with_new_sensors.empty?
        #need to identify the two largest spaces
        primary_area = 0
        secondary_area = 0
        primary_space = nil
        secondary_space = nil
        three_or_more_sensors = false

        # dfg temp - need to add another if statement so only get spaces with sensors
        zone_spaces_with_new_sensors.each do |zone_space|
          zone_space_area = zone_space.floorArea
          if zone_space_area > primary_area
            primary_area = zone_space_area
            primary_space = zone_space
          elsif zone_space_area > secondary_area
            secondary_area = zone_space_area
            secondary_space = zone_space
          else
            #setup flag to warn user that more than 2 sensors can't be added to a space
            three_or_more_sensors = true
          end

        end

        if primary_space
          #setup primary sensor
          sensor_primary = new_sensor_objects[primary_space.name.to_s]
          zone.setPrimaryDaylightingControl(sensor_primary)
          zone.setFractionofZoneControlledbyPrimaryDaylightingControl(primary_area/(primary_area + secondary_area))
        end

        if secondary_space
          #setup secondary sensor
          sensor_secondary = new_sensor_objects[secondary_space.name.to_s]
          zone.setSecondaryDaylightingControl(sensor_secondary)
          zone.setFractionofZoneControlledbySecondaryDaylightingControl(secondary_area/(primary_area + secondary_area))
        end

        #warn that additional sensors were not used
        if three_or_more_sensors == true
          runner.registerWarning("Thermal zone '#{zone.name}' had more than two spaces with sensors. Only two sensors were associated with the thermal zone.")
        end

      end #end if not zone_spaces.empty?

    end #end affected_zones.each do

    #setup OpenStudio units that we will need
    unit_area_ip = OpenStudio::createUnit("ft^2").get
    unit_area_si = OpenStudio::createUnit("m^2").get

    #define starting units
    area_si = OpenStudio::Quantity.new(sensor_area, unit_area_si)

    #unit conversion from IP units to SI units
    area_ip = OpenStudio::convert(area_si, unit_area_ip).get

    #reporting final condition of model
    runner.registerFinalCondition("Added daylighting controls to #{sensor_count} spaces, covering #{area_ip}.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddDaylightSensorsToSelectedSpaces.new.registerWithApplication