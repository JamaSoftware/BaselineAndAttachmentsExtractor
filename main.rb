require_relative 'config'
require_relative 'jama_client'

class Main
  @Config = Config.new
  @jamaClient = JamaClient.new

  ### Validate User Credentials and use for session

  validCredentials = @jamaClient.validate_credentials("ibilal", "RICKSONjama!@#")
  invalidCredentials = @jamaClient.validate_credentials("ibilal", "bob")

  puts validCredentials.to_s + " should be true"
  puts invalidCredentials.to_s + " should be false"

  validAuth = {:username => "ibilal", :password => "RICKSONjama!@#"}
  invalidAuth = {:username => "ibilal", :password => "wrong!@#"}

  valid = @jamaClient.validate(validAuth)
  invalid = @jamaClient.validate(invalidAuth)

  puts valid.to_s + " should be true"
  puts invalid.to_s + " should be false"

  valid_config = @jamaClient.validate_config_credentials
  puts valid_config.to_s + " should be true since credentials are valid"










  ### Provide Project matching name or error reason

  projects = @jamaClient.get_project_by_name("CoveragePlus - Agile")
  if projects == nil || projects.length < 0
    puts "No project found. Exiting now."
    exit(1)
  end

  if projects.length > 1
    puts "SEVERE: Multiple projects retrieved with name [" + @Config.project_name.to_s + "]"
    exit (1)
  end

  project = projects[0]
  puts "pause"









  ### Return a list of children objects for a given project, get a set by the set_id specified in Config.rb
  sets = []
  sets = project.get_sets
  a_set = nil

  for set in sets
    if set.id == @Config.set_id
      a_set = set
    end
  end
  puts "Set fields as object : " + a_set.get_fields.to_s
  puts "Set fields as string : " + a_set.get_fields_as_string
  puts "pause"








  ### For a given set, request baselines that match a given name (baseline name currently set in Config.rb)or return current version of set
  baselines = []
  baselines = a_set.get_baselines_by_name(@Config.baseline_name)
  # users can optionally request all baselines for an item, and will retrieve a list of baselines or the current version of the item
  all_baselines = a_set.get_baselines
  puts "pause"








  ### For a set baseline, request name, Global ID, unique ID, Description and Owner (owner concept not supported)
  for baseline in baselines
    puts "Baseline fields as object : " + baseline.get_fields.to_s
    puts "Baseline fields as string : " + baseline.get_fields_as_string
  end
  puts "pause"










  ### For a given set or baseline, request list of children
  children = []
  a_baseline = nil
  if baselines.length > 1
    for baseline in baselines
      if baseline.id == @Config.baseline_id
        a_baseline = baseline
      end
    end
  else
    a_baseline = baselines[0]
  end
  children = a_baseline.get_children
  puts "pause"








  ### For each child:
  # a. Retrieve item fields
  # b. Retrieve list of attachments for each item
  attachments = a_baseline.get_attachments
  puts "pause"


end