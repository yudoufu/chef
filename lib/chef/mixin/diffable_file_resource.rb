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

require 'chef/mixin/shell_out'

class Chef
  class Util
    class Diff
      include Chef::Mixin::ShellOut

      def initialize(source, dest)
        @suppress_resource_reporting = false
        diff(source, dest)
      end

      def to_s
        @string ? @string : @diff
      end

      def for_reporting
        # WARNING: caller needs to ensure that new files aren't posted to resource reporting
        @diff
      end

      def diff(source, dest)
        # these are internal errors that should never get raised
        raise "source file does #{source} not exist to diff against" unless File.exists?(source)
        raise "dest file #{dest} does not exist to diff against" unless File.exists?(dest)
        @string = catch (:nodiff) do
          @diff = do_diff(source, dest)
        end
      end

      private

      def do_diff(source, dest)
        throw :nodiff, "(diff output suppressed by config)" if Chef::Config[:diff_disabled]

        diff_filesize_threshold = Chef::Config[:diff_filesize_threshold]
        diff_output_threshold = Chef::Config[:diff_output_threshold]

        if ::File.size(target_path) > diff_filesize_threshold || ::File.size(path) > diff_filesize_threshold
          throw :nodiff, "(file sizes exceed #{diff_filesize_threshold} bytes, diff output suppressed)"
        end

        # MacOSX(BSD?) diff will *sometimes* happily spit out nasty binary diffs
        throw :nodiff, "(current file is binary, diff output suppressed)" if is_binary?(target_path)
        throw :nodiff, "(new content is binary, diff output suppressed)" if is_binary?(path)

        begin
          # -u: Unified diff format
          result = shell_out("diff -u #{target_path} #{path}" )
        rescue Exception => e
          # Should *not* receive this, but in some circumstances it seems that
          # an exception can be thrown even using shell_out instead of shell_out!
          throw :nodiff, "Could not determine diff. Error: #{e.message}"
        end

        # diff will set a non-zero return code even when there's
        # valid stdout results, if it encounters something unexpected
        # So as long as we have output, we'll show it.
        if not result.stdout.empty?
          if result.stdout.length > diff_output_threshold
            throw :nodiff, "(long diff of over #{diff_output_threshold} characters, diff output suppressed)"
          else
            val = result.stdout.split("\n")
            val.delete("\\ No newline at end of file")
            val = val.join("\\n")
            # XXX: we return the diff here, everything else is an error of one form or another
            return val
          end
        elsif not result.stderr.empty?
          throw :nodiff, "Could not determine diff. Error: #{result.stderr}"
        else
          throw :nodiff, "(no diff)"
        end
      end

      def is_binary?(path)
        ::File.open(path) do |file|

          buff = file.read(Chef::Config[:diff_filesize_threshold])
          buff = "" if buff.nil?
          return buff !~ /^[\r[:print:]]*$/
        end
      end

    end
  end
end

