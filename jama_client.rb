require 'rest_client'
require 'json'
require_relative 'config'
require_relative 'domain'

class JamaClient
  include RestClient
  include JSON


  def initialize
    @jamaConfig = Config.new
    @base_url = @jamaConfig.get_base_url != nil ? @jamaConfig.get_base_url : "none"
    @auth = {:username => @jamaConfig.username, :password => @jamaConfig.password}
    @username = @jamaConfig.username != nil ? @jamaConfig.username : "none"
    @password = @jamaConfig.password != nil ? @jamaConfig.password : "none"
    @item_types = Array.new
  end




  ### retrieve an item from the server by id, or null if item with id does not exist
  def get_item(id)
    url = @base_url.to_s + "items/#{id.to_s}"
    resource = RestClient::Resource.new url, @username, @password
    begin
      response = resource.get
      return JSON.parse(response.body)["data"]
    rescue Exception => e
      puts "Unable to process request. Error [" + e.to_s + "]"
      return nil
    end
  end


  ### retrieve a resource from the server by resource. Return response or nil if request fails
  def get(resource)
    url = @base_url.to_s + resource
    resource = RestClient::Resource.new url, @username, @password
    begin
      response = resource.get
      return response.body
      # return JSON.parse(response.body)["data"]
    rescue Exception => e
      puts "Unable to process request. Error [" + e.to_s + "]"
      return nil
    end
  end



  ### validate a user's credentials using the username and password arguments, return true if authorized user, false
  ### othwerwise
  def validate_credentials(username, password)
    url = @base_url.to_s + "users/current"
    resource = RestClient::Resource.new url, username, password
    begin
      resource.get
      return true
    rescue Exception => e
      if e.http_code == 401 && (e.message.to_s.include? "Unauthorized")
        puts "Unauthorized user"
      else
        puts "Something terrible went wrong see [" + e.to_s + "]"
      end
      return false
    end
  end



  ### validate a user's credentials using the object auth {:username => username, :password => password} to validate
  ### if user credentials are valid, return true if they are, false otherwise
  def validate(auth)
    url = @base_url.to_s + "users/current"
    resource = RestClient::Resource.new url, auth["username".to_sym], auth["password".to_sym]
    begin
      resource.get
      return true
    rescue Exception => e
      if e.http_code == 401 && (e.message.to_s.include? "Unauthorized")
        puts "Unauthorized user"
      else
        puts "Something terrible went wrong see [" + e.to_s + "]"
      end
      return false
    end
  end



  ### validate a user's credentials located in the config file (Config.rb), return true if credentials are valid, false
  ### otherwise
  def validate_config_credentials()
    url = @base_url.to_s + "users/current"
    resource = RestClient::Resource.new url, @jamaConfig.username, @jamaConfig.password
    begin
      resource.get
      return true
    rescue Exception => e
      if e.http_code == 401 && (e.message.to_s.include? "Unauthorized")
        puts "Unauthorized user"
      else
        puts "Something terrible went wrong see [" + e.to_s + "]"
      end
      return false
    end
  end



  ### Retrieve a project from the server given a project name argument, return nil if multiple projects found or no project
  ### is found. otherwise return the project
  def get_project_by_name(project_name)
    url = @base_url.to_s + "projects"
    resource = RestClient::Resource.new url, @jamaConfig.username, @jamaConfig.password
    project_array = Array.new
    begin
      response = resource.get
      projects = JSON.parse(response.body)
      for project in projects["data"]
        if project["fields"]["name"].to_s == project_name.to_s
          puts "Project [" + project_name.to_s + "] was found..."
          a_project = JamaProject.new(project)
          project_array.insert(-1, a_project)
        end
      end
      if project_array.length < 1
        puts "Project with name [" + project_name.to_s + "] does not exist in this instance. Please verify the project name exists and try again."
        return nil
      end
      return project_array
    rescue Exception => e
      puts "Something bad went wrong must handl"
    end
  end



  ### retrieve projects sets or nil if no sets exist
  def get_project_sets(project)
    set_id = get_item_type_id("SET")
    resource = "abstractitems?project=#{project["id"]}&itemType=#{set_id}"
    sets = get_all(resource)

    return sets
  end



  ### retrieve a set's baselines
  def get_set_baselines(set)
    baselines_to_return = Array.new
    baselines = get_all("baselines?project=#{set["project"].to_s}")
    if baselines.length > 0
      for baseline in baselines
        if baseline["origin"]["item"] == set["id"]
          baselines_to_return.insert(-1, baseline)
        end
      end
    end
    return baselines_to_return
  end



  ### retrieve originating item for a given baseline item
  def get_originating_set(baseline)
    set_to_return = {}
    set = get_item("items/#{baseline["origin"]["item"].to_s}")
    if set == nil
      return set_to_return
    end
    set_to_return = {:name => set["fields"]["name"], :globalId => set["globalId"], :uniqueId => set["documentKey"], :description => set["fields"]["description"]}
    return set_to_return
  end



  ### retrieve children of an object (baseline or set)
  def get_children(object)
    type = extract_type(object)
    if type == nil
      puts "SEVERE: Object [" + object.to_s + "] is of type nil. Exiting now."
      exit(1)
    end
    if type == "items"
      return get_set_children(object)
    elsif type == "baselines"
      children = get_baseline_children(object)
      if children == nil
        return Array.new
      else
        return children
      end
    else
      puts "SEVERE: Object [" + object.to_s + "] is not of type items or baselineitems. Exiting now. "
      exit(1)
    end
  end



  ### Retrieve baseline children
  def get_baseline_children(baseline)
    if baseline == nil
      return nil
    end
    resource = "baselines/#{baseline["id"].to_s}/versioneditems"
    children = get_all(resource)
    if children.class == Array
      return children
    else
      return nil
    end
  end



  ### get all items for a given resource
  def get_all(resource)
    begin
      all_results = Array.new
      results_remaining = true
      current_start_index = 0
      delim = resource.to_s.include?("?") ? "&" : "?"
      while results_remaining do
        start_at = delim.to_s + "startAt=#{current_start_index}"
        url = @jamaConfig.get_base_url.to_s + resource.to_s + start_at.to_s
        puts url.to_s
        rest_resource = RestClient::Resource.new url, @jamaConfig.username, @jamaConfig.password
        response = rest_resource.get
        json_response = JSON.parse(response.body)
        if json_response["meta"].include? "pageInfo" == false
          puts json_response.to_s
          return [json_response["data"]]
        end
        result_count = json_response["meta"]["pageInfo"]["resultCount"]
        total_results = json_response["meta"]["pageInfo"]["totalResults"]
        results_remaining = current_start_index.to_i + result_count.to_i != total_results.to_i
        current_start_index += 20
        all_results = all_results + json_response["data"]
      end
      return all_results
    rescue Exception => e
      puts "some data"
    end
  end



  ### retrieve itemType id given an itemType key
  def get_item_type_id(typeKey)
    if @item_types.length < 1
      resource = "itemtypes"
      item_types = get_all(resource)
      if item_types.length < 0
        return nil
      end
      @item_types = item_types
      return get_item_type_id_from_list(item_types, typeKey)
    else
      # todo check time and make sure it's time to fetch here, if not use the regualr list, else fetch
      return get_item_type_id_from_list(@item_types, typeKey)
    end
  end


  ### retrieve item type id from list given itemType key
  def get_item_type_id_from_list(list, typeKey)
    if list.class != Array || list.length < 0
      return nil
    end
    for item in list
      if item["typeKey"] == typeKey
        return item["id"]
      end
    end
    return nil
  end



  ### extract itemType from response object
  def extract_type(object)
    if object == nil
      return object
    else
      return object["type"]
    end
  end



  ### get item with documentKey matching argument document_key
  def get_item_for_documentkey(document_key)
    items = get_all("abstractitems?documentKey=#{document_key}")
    begin
      if items.length > 1
        raise Exception.new("Multiple items with ID: #{document_key}")
      elsif items.length < 1
        raise Exception.new("No items found with ID: #{document_key}")
      end
      return items[0]
    rescue Exception => e
      puts e
    end
  end


  def get_attachment_file(resource)
    response_body = get(resource)
    if response_body == nil
      return nil
    else
      puts "something here"
      return response_body
    end

  end
end
