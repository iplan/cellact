class FileMacros
  @@spec_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))


  class << self
    def spec_root
      @@spec_root
    end

    def view_file_path(view_file)
      File.join(@@spec_root, 'resources/views/', "#{view_file}.html.erb")
    end

    def load_xml_file(xml_file)
      File.read(File.join(@@spec_root, 'resources', xml_file))
    end

  end

end