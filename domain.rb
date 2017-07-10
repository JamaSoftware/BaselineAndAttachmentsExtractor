require_relative 'config'
require_relative 'jama_client'
require_relative 'item_tree'


=begin


JamaItem class is the base class of the entire hierarchy. From it the following classes are derived: JamaSet, JamaText, JamaBaseline, and Jama_MTRReq
An item cannot be created without all three of these items (name must not be nil, desc can be)


This base class contains getters/setters for its data members.


Data Members:
  @id           => a Jama item's ID
  @name         => a Jama item's name (required)
  @description  => a Jama item's description


=end


class Item

  ### Constructor
  def initialize(id, name, desc, itemType)
    @config = Config.new
    @jama_client = JamaClient.new
    @id = id
    @name = name
    @desc = desc
    @itemType = itemType
  end


  ### Retrieve item fields
  def get_fields
    fields = {:id => @id, :name => @name, :desc => @desc, :itemType => @itemType}
    return fields
  end


  ### Retrieve item fields
  def get_fields_as_string
    fields = "{ id => #{@id}, name => #{@name}, desc => #{@desc}, itemType => #{@itemType} }"
    return fields
  end


  ### Return name
  def name
    @name
  end


  ### Return @desc
  def desc
    @desc
  end


  ### Return @id
  def id
    @id
  end


  ### Return itemType
  def itemType
    @itemType
  end

  ### Set @name
  def name=(name)
    @name = name
  end


  ### Set @desc
  def desc=(desc)
    @desc = desc
  end


  ### Set @id
  def id=(id)
    @id = id
  end


  ### Set @itemType
  def itemType=(itemType)
    @itemType = itemType
  end


  ### Return true if value matches @name , false otherwise
  def name_match(value)
    if @name != nil and @name == value
      return true
    end
    return false
  end


  ### Return true if value matches @id, false otherwise
  def id_match(value)
    if @id != nil and @id == value
      return true
    end
    return false
  end


  ### Return true if itemType matches value, false otherwise
  def type_match(value)
    if @itemType != nil and @itemType == value
      return true
    end
    return false
  end


end


=begin


JamaProject class is a subclass of JamaItem. This class contains getters/setters for the list of children objects of
type SET.


The getter will only retrieve data from the API when the lifetime of an item has ended. This is determined by a datetime
object called last_fetched.


Data Members:
  @config           => to pull in configuration information
  @jama_client      => to retrieve data from the API
  @children         => list of children objects of type SET
  @last_fetched     => date/time object of the last time the project's children were fetched
  @fetched          => boolean object indicating whether or not a fetch has taken place
  @lifetime         => integer object of amount of time an object is alive for, retrieved from the config
  @has_children     => boolean object determines whether or not the project has any children

=end


class JamaProject < Item

  ### Constructor
  def initialize(projectJson)
    super(projectJson["id"], projectJson["fields"]["name"], projectJson["fields"]["description"], "Project")
    @children = []
    @last_fetched = nil
    @fetched = false
    @lifetime = @config.timeout
    @has_children = false
  end


  ### Manage retrieving list of children for a given project of type SET. Verify the children need to be fetched (either have
  # never been fetched, or have been fetched too long ago), before fetching, and returning @children.
  def get_sets
    if should_fetch
      fetch_sets
    end
    return @children
  end


  ### Retrieve list of children for project of type SET
  def fetch_sets()
    set_id = @jama_client.get_item_type_id("SET")
    resource = "abstractitems?project=#{@id.to_s}&itemType=#{set_id}"
    sets = @jama_client.get_all(resource)
    for item in sets
      jamaSet = JamaSet.new(item)
      jamaSet.set_project(self)
      @children << jamaSet
    end
    if @children.length > 0
      @has_children = true
    else
      @has_children = false
    end
    @fetched = true
    @last_fetched = Time.now
  end


  ### Return true if project's children have not been fetched, or if they haven't been fetched recently
  def should_fetch()
    if !@fetched
      return true
    elsif Time.now - @last_fetched > @lifetime
      return true
    end
    return false
  end


  ### Check if the project has children
  def has_children()
    if !should_fetch
      fetch_sets
    end
    return @has_children
  end

end


=begin


JamaSet class is a subclass of JamaItem. This class contains getters/setters for the list of children items


The getter will only retrieve data from the API when the lifetime of an item has ended. This is determined by a datetime
object called last_fetched.


Data Members:
  @jama_client      => to retrieve data from the API
  @global_id        => Jama set's global ID
  @unique_id        => Jama set's document Key
  @owner            => not a concept in Jama but leaving in per customer request
  @baselines        => list of baselines items for set (or current version of set)
  @baseline_type    => type of baseline retrieved (could be set if no baselines exist for the set)
  @baseline_fetch   => object to track the status and last_fetched date/time of baselines
  @children         => list of children objects in hierarchy tree
  @children_fetch   => object to track the status and last_fetched date/time of children
  @config           => configuration file
  @project          => originating project for set
  @has_children     => boolean object determines whether or not the set has any children

=end


class JamaSet < Item


  ### Constructor
  def initialize(set)
    super(set["id"], set["fields"]["name"], set["fields"]["description"], "Set")
    @global_id = set["globalId"]
    @unique_id = set["documentKey"]
    @owner = nil

    @baselines = []
    @baseline_type = nil
    @baseline_fetch = {:fetched => false, :last_fetched => nil}

    @children = []
    @children_fetch = {:fecthed => false, :last_fetched => nil}

    @project = nil
    @has_children = false
    @item_tree = nil
  end


  ### Assign source project for the set
  def set_project(project)
    @project = project
  end


  ### Get Set fields
  def get_fields
    fields = super
    fields = fields.merge({:globalId => @global_id, :uniqueId => @unique_id})
    return fields
  end


  ### Get Set fields as string
  def get_fields_as_string
    fields = super
    fields = fields.split("}")[0] + ", globalId => #{@global_id}, uniqueId => #{@unique_id} }"
    return fields
  end


  ### Manage retrieving list of children for a given set. Verify the children need to be fetched (either have
  # never been fetched, or have been fetched too long ago), before fetching, and returning @children.
  def get_children
    if should_fetch_children
      fetch_children
    end
    return @children
  end


  ### Return true if set's children have not been fetched, or if they haven't been fetched recently
  def should_fetch_children
    if !@children_fetch[:fecthed]
      return true
    elsif Time.now - @children_fetch[:last_fetched] > @config.timeout
      return true
    end
    return false
  end


  ### Retrieve list of children for set
  def fetch_children
    @item_tree = ItemTree.new(@unique_id, @project.id)
    children = @item_tree.get_tree_list
    @children = classify_children(children)
    if @children.length > 0
      @has_children = true
    end
    return @children
  end



  ### Classify children of a set as folder, text, or requirement
  def classify_children(children)
    text_id = @jama_client.get_item_type_id(@config.text_key)
    folder_id = @jama_client.get_item_type_id(@config.folder_key)
    requirement_id = @jama_client.get_item_type_id(@config.requirement_key)
    set_id = @jama_client.get_item_type_id(@config.set_key)
    to_return = []
    for child in children
      item = nil
      if child["itemType"] == text_id
        item = JamaText.new(child)
      elsif child["itemType"] == folder_id
        item = JamaFolder.new(child)
      elsif child["itemType"] == requirement_id
        item = JamaRequirement.new(child)
      elsif child["itemType"] == set_id
        item = JamaSet.new(child)
      else
        puts "Item [" + child.to_s + "] is not of required type and will be skipped."
      end
      if item != nil
        to_return << item
      end
      if child["children"] != nil and child["children"].length > 0
        to_return = to_return + classify_children(child["children"])
      end
    end
    return to_return
  end


  ### Retrieve list of baselines for set
  def fetch_baselines()
    baselines = []
    baselines = baselines + @jama_client.get_all("baselines?project=#{@project.id.to_s}")
    if baselines.length > 0
      for baseline in baselines
        if baseline["origin"]["item"] == @id
          jamaBaseline = Baseline.new(baseline)
          jamaBaseline.set_origin(self)
          jamaBaseline.set_project(baseline["project"])
          @baselines << jamaBaseline
        end
      end
    end
    if @baselines.length > 0
      @baseline_type = "Baseline"
    else
      @baseline_type = "Set"
    end
  end


  ### Return true if set's baselines have not been fetched, or if they haven't been fetched recently
  def should_fetch_baselines()
    if !@baseline_fetch[:fecthed]
      return true
    elsif Time.now - @baseline_fetch[:last_fetched] > @config.timeout
      return true
    end
    return false
  end


  ### Retrieve list of baselines for set
  def get_baselines
    if should_fetch_baselines
      fetch_baselines
    end
    if @baselines.length < 1
      @baselines = []
      @baselines << self # add current version of set to list and return
    end
    return @baselines
  end


  ### Retrieve list of baselines for set matching a given name
  def get_baselines_by_name(baseline_name)
    if should_fetch_baselines
      fetch_baselines
    end
    to_return = []
    for baseline in @baselines
      if baseline.name == baseline_name
        to_return << baseline
      end
    end
    if to_return.length < 1
      to_return << self
    end
    return to_return
  end


  def get_baseline_type
    if !should_fetch_baselines
      fetch_baselines
    end
    return @baseline_type
  end


  def get_attachments()
    attachments = retrieve_attachments_recursively(@children)
    return attachments
  end


  def retrieve_attachments_recursively(children)
    attachments = []
    for child in children
      attachments = attachments + child.get_attachments
    end
    return attachments
  end


  ### Check if the set has children
  def has_children()
    if !should_fetch_children
      fetch_children
    end
    return @has_children
  end

end


=begin


JamaBaseline class is a subclass of JamaItem. This class contains getters/setters for the list of children objects, as
well as its originating set object and project.


The getter will only retrieve data from the API when the lifetime of an item has ended. This is determined by a datetime
object called children_fetch.


Data Members:
  @children         => list of children objects in hierarchy tree
  @children_fetch   => object to track the status and last_fetched date/time of children
  @project          => originating project for set
  @origin           => originating set object
  @has_children     => boolean object determines whether or not the baseline has any children

=end


class Baseline < Item
  def initialize(baseline)
    super(baseline["id"], baseline["name"], baseline["description"], "Baseline")
    @origin = nil
    @children = []
    @attachments = []
    @project = nil
    @children_fetch = {:fetched => false, :last_fetched => nil}
    @attachments_fetch = {:fetched => false, :last_fetched => nil}
    @has_children = false
    @lifetime = @config.timeout

  end


  ### Set project for baseline
  def set_project(project)
    @project = project
  end


  ### Get project for baseline
  def project()
    return @project
  end


  ### Get baseline fields
  def get_fields
    fields = super
    fields = fields.merge({:origin => @origin.id.to_s, :project => @project})
    return fields
  end


  ### Get baseline fields as string
  def get_fields_as_string
    fields = super
    fields = fields.split("}")[0] + ", origin => #{@origin.id.to_s}, project => #{@project} }"
    return fields
  end


  ### Set origin set
  def set_origin(set)
    @origin = set
  end


  ### Get origin set
  def origin
    return @origin
  end


  ### Manage retrieving list of children for a given baseline. Verify the children need to be fetched (either have
  # never been fetched, or have been fetched too long ago), before fetching, and returning @children.
  def get_children
    if should_fetch_children
      fetch_children
    end
    return @children
  end


  ### Return true if baseline's children have not been fetched, or if they haven't been fetched recently
  def should_fetch_children
    if !@children_fetch[:fecthed]
      return true
    elsif Time.now - @children_fetch[:last_fetched] > @lifetime
      return true
    end
    return false
  end


  ### Return true if baseline's attachments have not been fetched, or if they haven't been fetched recently
  def should_fetch_attachments
    if !@attachments_fetch[:fecthed]
      return true
    elsif Time.now - @attachments_fetch[:last_fetched] > @lifetime
      return true
    end
    return false
  end



  ### Retrieve list of children for set
  def fetch_children
    #todo fix this and make it work with tree set from post processing
    @children = []
    resource = "baselines/#{@id.to_s}/versioneditems"
    children = @jama_client.get_all(resource)
    text_id = @jama_client.get_item_type_id(@config.text_key)
    folder_id = @jama_client.get_item_type_id(@config.folder_key)
    requirement_id = @jama_client.get_item_type_id(@config.requirement_key)

    for child in children
      item = nil
      if child["itemType"] == text_id
        item = JamaText.new(child)
      elsif child["itemType"] == folder_id
        item = JamaFolder.new(child)
      elsif child["itemType"] == requirement_id
        item = JamaRequirement.new(child)
      else
        puts "Item [" + child.to_s + "] is not of required type and will be skipped."
      end
      if item != nil
        @children << item
      end
    end

    @children_fetch[:fecthed] = true
    @children_fetch[:last_fetched] = Time.now
    if @children.length > 0
      @has_children = true
    end
  end


  ### Check if the baseline has children
  def has_children()
    if should_fetch_children
      fetch_children
    end
    return @has_children
  end


  def get_attachments()
    if should_fetch_attachments
      retrieve_attachments_recursively(@children)
      return @attachments
    else
      return @attachments
    end

  end


  def retrieve_attachments_recursively(children)
    for child in children
      @attachments = @attachments + child.get_attachments
    end
  end

end


=begin


JamaBaseline class is a subclass of JamaItem. This class contains getters/setters for the list of children objects, as
well as its originating set object and project.


The getter will only retrieve data from the API when the lifetime of an item has ended. This is determined by a datetime
object called children_fetch.


Data Members:
  @has_children     => boolean object determines whether or not the text item has any children

=end


class JamaText < Item

  def initialize(text)
    @config = Config.new
    super(text["id"], text["fields"]["name"], text["fields"]["desc"], @config.text_key)
    @attachments = []
    @fetched = false
    @last_fetched = nil
    @lifetime = @config.timeout
  end


  def itemType
    return @itemType
  end

  def get_attachments
    if should_fetch
      fetch_attachments
    end
    return @attachments
  end


  def should_fetch
    if !@fetched
      return true
    elsif Time.now - @last_fetched > @lifetime
      return true
    end
    return false
  end

  def fetch_attachments
    resource = "items/#{@id.to_s}/attachments"
    attachments = @jama_client.get_all(resource)
    if attachments.length < 1
      return
    end
    for attachment in attachments
      jama_attachment = Attachment.new(attachment)
      @attachments << jama_attachment
    end
    @fetched = true
    @last_fetched = Time.now
  end

end


class JamaFolder < Item

  def initialize(folder)
    @config = Config.new
    super(folder["id"], folder["fields"]["name"], folder["fields"]["desc"], @config.folder_key)
    @attachments = []
    @fetched = false
    @last_fetched = nil
    @lifetime = @config.timeout

  end


  def itemType
    return @itemType
  end


  def get_attachments
    if !should_fetch
      fetch_attachments
    end
    return @attachments
  end


  def should_fetch
    if !@fetched
      return true
    elsif Time.now - @last_fetched > @lifetime
      return true
    end
    return false
  end


  def fetch_attachments
    resource = "items/#{@id.to_s}/attachments"
    attachments = @jama_client.get_all(resource)
    if attachments.length < 1
      return
    end
    for attachment in attachments
      jama_attachment = Attachment.new(attachment)
      @attachments << jama_attachment
    end
    @fetched = true
    @last_fetched = Time.now
  end


end


class JamaRequirement < Item

  def initialize(requirement)
    @config = Config.new
    super(requirement["id"], requirement["fields"]["name"], requirement["fields"]["desc"], @config.requirement_key)
    @attachments = []
    @fetched = false
    @last_fetched = nil
    @lifetime = @config.timeout
    @project_id = requirement["project"]
    @priority = requirement["fields"]["priority"]
    @device_applicability = requirement["fields"]["device_applicability$122"]
    @status = requirement["fields"]["status$122"]
    @change_type = requirement["fields"]["change_type$122"]
    @change_reason = requirement["fields"]["change_reason$122"]
  end


  def itemType
    return @itemType
  end


  def get_attachments
    if should_fetch
      fetch_attachments
    end
    return @attachments
  end


  def should_fetch
    if !@fetched
      return true
    elsif Time.now - @last_fetched > @lifetime
      return true
    end
    return false
  end


  def fetch_attachments
    resource = "items/#{@id.to_s}/attachments"
    attachments = @jama_client.get_all(resource)
    if attachments.length < 1
      @fetched = true
      @last_fetched = Time.now
      return
    end
    for attachment in attachments
      jama_attachment = Attachment.new(attachment)
      @attachments << jama_attachment
    end
    @fetched = true
    @last_fetched = Time.now
  end


  ### Get requirement fields
  def get_fields
    fields = super
    fields = fields.merge({:project_id => @project_id.to_s, :priority => @priority,
                           :device_applicability => @device_applicability, :status => @status,
                           :change_type => @change_type, :change_reason => @change_reason})
    return fields
  end


  ### Get requirement fields as string
  def get_fields_as_string
    fields = super
    fields = fields.split("}")[0] + "project_id => #{@project_id.to_s}, priority => #{@priority},
                           device_applicability => #{@device_applicability}, status => #{@status},
                           change_type => #{@change_type}, change_reason => #{@change_reason} }"
    return fields
  end

end









class Attachment < Item

  def initialize(attachment)
    super(attachment["id"], attachment["fields"]["name"], "", "ATT")
    @filename = attachment["fileName"]
    @url = @config.get_base_url + "attachments/#{@id}/file"
    @name = attachment["fields"]["name"]
    @path_to_file = nil
    download_file(@id)
  end


  def download_file(id)
    resource = "attachments/#{id.to_s}/file"
    file_data = @jama_client.get_attachment_file(resource)
    if file_data != nil
      file = File.new(@filename, 'w')
      file.write file_data
      file.close
      @path_to_file = file.path.to_s
    end
  end

end

