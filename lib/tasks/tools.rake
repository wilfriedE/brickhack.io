namespace :tools do
  desc "Prints a list of accepted & confirmed attendees from a specific school in CSV format"
  task :bus_list, [:school_name] => :environment do |t, args|
    school_name = args[:school_name]
    if school_name.blank?
      abort("Usage: rake tools:bus_list[\"school_name\"]")
    end
    school_id = School.where(name: school_name).first.id
    a = Questionnaire.where("school_id = :school_id AND acc_status = \"rsvp_confirmed\" OR school_id = :school_id AND acc_status = \"accepted\"", school_id: school_id).map { |q| q.first_name + "," + q.last_name + "," + q.email + "," + Questionnaire::POSSIBLE_ACC_STATUS[q.acc_status] }
    puts "First Name,Last Name,Email,Status\n"
    puts a.join("\n")
  end

  desc "Removes all users/questionnaires and resets school questionnaire counts"
  task :reset_questionnaires, [] => :environment do |t, args|
    puts "Deleting all questionnaires..."
    Questionnaire.delete_all
    puts "Deleting all users..."
    User.delete_all
    puts "Resetting all school questionnaire counts..."
    School.where("questionnaire_count > 0").update_all questionnaire_count: 0
  end

  private

  def copy_file_to_folder(client, file_id, new_folder_id, new_file_name)
    drive = client.discovered_api('drive', 'v2')
    new_file_body = {
      title: new_file_name,
      parents: [
        {
          id: new_folder_id
        }
      ]
    }
    begin
      result = client.execute(
        api_method:  drive.files.copy,
        body_object: new_file_body,
        parameters:  { fileId: file_id }
      )
      if result.status == 200
        return result.data
      else
        puts "** Error: #{file_id} could not be moved: #{result.data['error']['message']}"
        if result.data['error']['message'] == "User rate limit exceeded"
          raise "Rate Limit Exceeded"
        end
      end
    rescue => e
      if e.message == "Rate Limit Exceeded"
        puts "Sleeping..."
        sleep 5
        retry
      end
    end
  end

  def delete_file(client, file_id, folder_id)
    begin
      result = client.execute(
        api_method: drive.files.delete,
        parameters:  { fileId: file_id, folder_id: folder_id }
      )
      if result.status == 200
        return result.data
      else
        puts "** Error: #{file_id} could not be deleted: #{result.data['error']['message']}"
        if result.data['error']['message'] == "User rate limit exceeded"
          raise "Rate Limit Exceeded"
        end
      end
    rescue => e
      if e.message == "Rate Limit Exceeded"
        puts "Sleeping..."
        sleep 5
        retry
      end
    end
  end

  # Copied from storage/google_drive.rb /w modifications

  def search_for_title(title, folder_id)
    parameters = {
            folderId: folder_id,
            q:        "title = '#{title}'",
            fields:   "items/id"
    }
    client = google_api_client
    drive  = client.discovered_api('drive', 'v2')
    result = client.execute(api_method: drive.children.list, parameters: parameters)
    if result.status == 200 && result.data.items.length > 0
      result.data.items[0]['id']
    end
  end

  def parse_credentials(credentials)
    credentials.symbolize_keys
  end

  # Copied from storage/google_drive.rb, no modifications

  def google_api_client
    @google_api_client ||= begin
      assert_required_keys
      client = Google::APIClient.new(:application_name => 'ppc-gd', :application_version => PaperclipGoogleDrive::VERSION)
      client.authorization.client_id = @google_drive_credentials[:client_id]
      client.authorization.client_secret = @google_drive_credentials[:client_secret]
      client.authorization.access_token = @google_drive_credentials[:access_token]
      client.authorization.refresh_token = @google_drive_credentials[:refresh_token]
      client
    end
  end

  def assert_required_keys
    keys_list = [:client_id, :client_secret, :access_token, :refresh_token]
    keys_list.each do |key|
      @google_drive_credentials.fetch(key)
    end
  end
end
