require_relative 'jama_client'
require_relative 'config'
require_relative 'domain'
class ItemTree

  def initialize(documentKey, project)
    @config = Config.new
    @document_key = documentKey
    @jama_client = JamaClient.new
    @target_project = project
    @sequence_map = {}
    item_list = @jama_client.get_all("items?project=#{@target_project}")
    item_list = sanitize_items(item_list)
    @true_root = nil
    @folder_id = nil
    @text_id = nil
    @requirement_id = nil

    for item in item_list
      if item["documentKey"] == @document_key
        @true_root = item
      end
      @sequence_map[item["location"]["sequence"]] = item
      item["children"] = []
    end
    roots = []

    for item in item_list
      seq = item["location"]["sequence"]
      parent_seq = get_parent_sequence_number(seq)
      if parent_seq == ""
        roots << item
      else
        begin
          get_iterable_children_list(@sequence_map[parent_seq]) << item
        rescue KeyError => e
          puts "couldn't find key for item " + json.dumps(item)

        end
      end
    end
    sort_forest(roots)
    puts "done"
  end


  def sort_forest(root_list)
    root_list.sort_by { |item| item["location"]["sequence"] }
    for item in root_list
      sort_forest(get_iterable_children_list(item))
    end
  end


  def get_parent_sequence_number(seq)
    return seq[0, seq.to_s.rindex(".") != nil ? seq.to_s.rindex(".") : 0]
    # puts "something to stall"
    # return seq[:seq.rfind(".")]
  end


  def to_depth_first(root)
    result = [root]
    for child in get_iterable_children_list(root)
      result = result + to_depth_first(child)
      return result
    end
  end


  def get_iterable_children_list(item)
    if item["children"] == nil
      return []
    else
      return item["children"]
    end
  end


  def sanitize_items(item_list)
    new_item_list = []
    item_hit = 0
    item_miss = 0
    total = 0
    for item in item_list
      total = total + 1
      item = @jama_client.get_item(item["id"])
      if item != nil
        # actual_item = extract_item(item)
        item_hit = item_hit + 1
        new_item_list << item
        # new_item_list << actual_item
        puts "hit"
      else
        item_miss = item_miss + 1
        puts "miss"
      end
    end

    puts "total items processed " + total.to_s + ". Total misses were " + item_miss.to_s + " while Total hits were " + item_hit.to_s
    return new_item_list
  end


  def extract_item(item)
    if @folder_id == nil
      @folder_id = @jama_client.get_item_type_id(@config.folder_key)
    end
    if @text_id == nil
      @text_id = @jama_client.get_item_type_id(@config.text_key)
    end
    if @requirement_id == nil
      @requirement_id = @jama_client.get_item_type_id(@config.requirement_key)
    end
    if @set_id == nil
      @set_id = @jama_client.get_item_type_id(@config.set_key)
    end

    if item["itemType"] == @folder_id
      return JamaFolder.new(item)
    elsif item["itemType"] == @text_id
      return JamaText.new(item)
    elsif item["itemType"] == @requirement_id
      return JamaRequirement.new(item)
    elsif item["itemType"] == @set_id
      return JamaSet.new(item)
    else
      raise Exception.new("Unable to process item [" + item.to_s + "]. Item not of type FLD, TXT, or Requirement")
    end


  end


  def get_tree_list
    flatList = to_depth_first(@true_root)
    return flatList
  end


  def atoi(item)
    if item.is_a?(Numeric)
      return item.to_i
    else
      return item
    end
  end


  def natural_keys(item)
    array = []
    for c in re.split('(\d+)', item["location"]["sequence"])
      array << atoi(c)
    end
    return array
  end

end
