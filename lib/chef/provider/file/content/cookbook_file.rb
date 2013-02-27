#
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider/file/content'

class Chef
  class Provider
    class File
      class Content
        class CookbookFile < Chef::Provider::File::Content

          private

          def file_for_provider
            cookbook = run_context.cookbook_collection[resource_cookbook]
            file_cache_location = cookbook.preferred_filename_on_disk_location(run_context.node, :files, @new_resource.source, @new_resource.path)
            if file_cache_location.nil?
              nil
            else
              tempfile = Tempfile.open(tempfile_basename, ::File.dirname(@new_resource.path))
              tempfile.close
              Chef::Log.debug("#{@new_resource} staging #{file_cache_location} to #{tempfile.path}")
              FileUtils.cp(file_cache_location, tempfile.path)
              tempfile
            end
          end

          def tempfile_basename
            basename = ::File.basename(@new_resource.name)
            basename.insert 0, "." unless Chef::Platform.windows?  # dotfile if we're not on windows
            basename
          end

          def resource_cookbook
            @new_resource.cookbook || @new_resource.cookbook_name
          end
        end
      end
    end
  end
end
