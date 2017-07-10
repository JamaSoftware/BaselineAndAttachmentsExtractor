class Config

  def initialize
    ## fill in the following config options:
    @username = "username"
    @password = "password"
    @url = "https://{base_url}.jamacloud.com/"


    ## System configurations (only requirement_key should be adjusted to suit your intended itemType)
    @rest_url = "rest/v1/"
    @base_url = @url + @rest_url
    @timeout = 10               ## Adjust to desired timeout for a given "fetch"
    @text_key = "TXT"
    @folder_key = "FLD"
    @requirement_key = "EP"     ## Substitute with Requirement ItemType Key
    @set_key = "SET"


    ## not needed => used for testing purposes
    # @set_id = 2186324
    @set_id = 2186324
    @baseline_id = 17843
    @attachment_id = 2190133
    @baseline_name = "NEW NEW"


  end

  def username
    @username
  end

  def password
    @password
  end

  def get_base_url
    @base_url
  end

  def project_name
    @project_name
  end

  def baseline_name
    return @baseline_name
  end

  def set_id
    @set_id
  end

  def baseline_id
    @baseline_id
  end

  def timeout
    @timeout
  end

  def text_key
    @text_key
  end

  def folder_key
    @folder_key
  end

  def requirement_key
    @requirement_key
  end
  def set_key
    @set_key
  end


end