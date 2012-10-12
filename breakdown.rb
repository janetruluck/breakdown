#!/usr/bin/ruby

require 'rubygems'
require 'pivotal-tracker'
require 'time'
require 'gmail'
require 'octokit'
require 'json/pure'

##########################################################
## Data
accounts_path = File.join(Dir.pwd, "accounts.json")
accounts_file = File.read(accounts_path)
accounts      = JSON.parse(accounts_file)

data_path = File.join(Dir.pwd, "data.json")
data_file = File.read(data_path)
data      = JSON.parse(data_file)

emails             = data["emails"]
people             = data["names"]
company            = data["company"]
repository         = accounts["github"]["repository"]
pivotal_project_id = accounts["pivotal"]["project_id"]

##########################################################
## Pivotal

token = PivotalTracker::Client.token(accounts["pivotal"]["email"],
                                     accounts["pivotal"]["password"])

PivotalTracker::Client.token = token
PivotalTracker::Client.use_ssl = true

project = PivotalTracker::Project.find(pivotal_project_id)

content = "Generated: #{Time.now}
           <h3>#{company} Breakdown</h3>
           <table border='1' cellpadding='5'>
           <tr><th>Name</th><th>Delivered to You</th><th>In Progress</th><th>Unstarted</th></tr>"

people.each do |person|
  delivered = project.stories.all(:requested_by  => person,
                                :current_state => "delivered").count
  progress  = project.stories.all(:owned_by => person,
                                :current_state => "started").count
  unstarted = project.stories.all(:owned_by => person,
                                :current_state => "unscheduled").count
  content += "<tr><td>#{person}</td><td>#{delivered}</td><td>#{progress}</td><td>#{unstarted}</td></tr>"
end


content += "</table>"
content += "Note: If you have 0's in all columns than either your name is spelled wrong or your work is not being tracked. Please let me know if either is the case!"

##########################################################
## Github

client = Octokit::Client.new(:login    => accounts["github"]["email"],
                             :password => accounts["github"]["password"])

pulls = client.pull_requests(repository)

content += "<br/><br/><h2/>There are <b>#{pulls.count}</b> open Pull Requests.</h2><br/><br/><b>Pull Requests<b/><br/>"
content += "<table border='1' cellpadding='5'>
              <tr><th>Pull Request</th><th>Age</th><th>+1 needed</th></tr>"

pulls.each do |pull|
  time = Time.now - Time.parse(pull.created_at)
  mm, ss = time.divmod(60)
  hh, mm = mm.divmod(60)
  dd, hh = hh.divmod(24)

  plus_one_counter = 0
  comments = client.issue_comments(repository, pull.number)

  comments.each do |comment|
    if comment.body.include?(":+1:")
      plus_one_counter += 1
    end
  end


  content += "<tr>
                  <td><a href='#{pull.url}'>#{pull.title}</a></td>
                  <td>%d days, %d hours, %d minutes and %d seconds</td>
                  <td>#{2 - plus_one_counter}</td>
              </tr>" % [dd, hh, mm, ss]
end

content += "</table>"

##########################################################
## Gmail

from      = accounts["gmail"]["email"]
recipient = emails
pass      = accounts["gmail"]["password"]

gmail = Gmail.new(from, pass)

email = gmail.generate_message do
  to emails
  subject "#{company} Breakdown"
  html_part do
    content_type 'text/html; charset=UTF-8'
    body content
  end
end

gmail.deliver(email)
