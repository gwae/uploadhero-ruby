#                              ___ _ _ _ ___ ___ 
#                             | . | | | | .'| -_|
#                             |_  |_____|__,|___|
#                             |___|      02-2013
#              
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
# Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

# Usage : 
#   uploadhero = Uploadhero.new 'user', 'pass'
#   10.times do
#       uploadhero.upload '/etc/passwd'
#   end
#   uploadhero.delete_all
#

require 'net/http'

class Uploadhero

    def initialize username, password
        @username = username
        @password = password
        @logged = false
        @uri = ''
        @params = ''
    end

    def check_account
        return true if @logged == true
        uri = URI('http://api.uploadhero.com/checkaccount.php')
        params = { 'username' => @username, 'password' => @password }
        uri.query = URI.encode_www_form(params)
        res = Net::HTTP.get_response(uri)
        if res.body =~ /Invalid Username\/password/
            false
        else
            true
        end
    end

    def login
        raise 'Invalid Username/password' unless check_account

        uri = URI('http://api.uploadhero.com/upload.php')
        params = { 'u' => @username, 'p' => @password }
        uri.query = URI.encode_www_form(params)
        res = Net::HTTP.get_response(uri)
        raise 'Query response != HTTPOK' if res.code != "200"
        @logged = true

        # We don't need to fire up rexml..
        res.body =~ /<upload_url>(.*)<\/upload_url>/
        @uri = $1
        res.body =~ /<params>ID=(.*)<\/params>/
        @params = $1

    end

    def upload file
        login unless @logged
        raise 'Wrong perms on the file' unless File.readable? file

        # Still looking for moar sexy (and portable ?) way to upload...
        cmd = "curl -silent -F 'Filedata=@#{file}' -F 'ID=#{@params}' #{@uri}"
        res = `#{cmd}`

        raise 'Upload error !' if res =~ /upload_error/
        id = res.split("Content-Type: text/html")[1].strip
        'http://uploadhero.com/dl/' + id
    end

    def list 
        raise 'Invalid Username/password' unless check_account

        uri = URI('http://api.uploadhero.com/manager.php')
        params = { 'username' => @username, 'password' => @password, 'action' => 'list' }
        uri.query = URI.encode_www_form(params)
        res = Net::HTTP.get_response(uri)

        raise 'Query response != HTTPOK' if res.code != "200"

        files = []
        res.body.split("\n").each do |line|
            line =~ /FILEID=([0-9a-zA-Z]{8}) => (.*)/
            files << { :id => $1, :path => $2.rstrip }
        end

        return files
    end

    def print_list
        list.each do |file|
            puts "#{file[:id]} - #{file[:path]}"
        end
    end

    def delete id
        raise 'Invalid Username/password' unless check_account

        uri = URI('http://api.uploadhero.com/manager.php')
        params = { 'username' => @username, 'password' => @password, 'fileid' => id, 'action' => 'delete' }
        uri.query = URI.encode_www_form(params)
        res = Net::HTTP.get_response(uri)

        raise 'Query response != HTTPOK' if res.code != "200"
        if res.body =~ /true/
            true
        else
            raise 'Invalid FILEID'
        end
    end

    def delete_all
        list.each do |file|
            delete file[:id]
        end
    end

end