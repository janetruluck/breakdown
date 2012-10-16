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

company            = accounts["company"]
repository         = accounts["github"]["repository"]
pivotal_project_id = accounts["pivotal"]["project_id"]

##########################################################
## Pivotal

token = PivotalTracker::Client.token(accounts["pivotal"]["email"],
                                     accounts["pivotal"]["password"])

PivotalTracker::Client.token = token
PivotalTracker::Client.use_ssl = true

project = PivotalTracker::Project.find(pivotal_project_id)

member_info    = Hash.new
members        = project.memberships.all
emails         = members.collect{ |member| member.email if member.role == "Member" || member.role == "Owner" }.compact
bugs           = project.stories.all(:story_type => 'bug')
backlog        = project.stories.all(:current_state => 'unstarted')
backlog_points = backlog.collect{ |story| story.estimate.to_i }.inject{ |sum, n| sum + n }

content = "Generated: #{Time.now}
           <h3>#{company} Breakdown</h3>
           Current Velocity: <b>#{project.current_velocity}</b> | Points in Backlog: <b>#{backlog_points}</b> | Bugs: <b>#{bugs.count}</b>
           <table border='1' cellpadding='5'>
           <tr><th>Name</th><th>Delivered to You</th><th>In Progress</th><th>Unstarted</th></tr>"


members.each do |member|
  if member.role == "Member" || member.role == "Owner"
    delivered = project.stories.all(:requested_by  => member.name,
                                    :current_state => "delivered").count
    progress  = project.stories.all(:owned_by => member.name,
                                    :current_state => "started").count
    unstarted = project.stories.all(:owned_by => member.name,
                                    :current_state => "unscheduled").count

    current   = "<tr><td>#{member.name}</td><td>#{delivered}</td><td>#{progress}</td><td>#{unstarted}</td></tr>"

    total     = delivered + progress + unstarted

    member_info["#{member.name}"] = { :total => total, :content => current}
  end
end

member_info = member_info.sort_by{ |key, val| val[:total] }.reverse

member_info.each do |key, val|
  content += val[:content]
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
                  <td><a href='#{pull._links.html.href}'>#{pull.title}</a></td>
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
