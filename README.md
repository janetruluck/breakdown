##Breakdown

Breakdown is a script to send an email with a "breakdown" of some metrics from Pivotal Tracker and Github

##How to Use
Just clone this repo down, update the json files to your correct information and run

    ruby breakdown.rb

##Example json files

Example files are included in the repo, just modify them to your needs

###accounts.json

This file is used to store the account information for your Github, Pivotal Tracker, and GMail. For example:

    {
      "pivotal":{
        "email":"test@example.com",
        "password":"super_secret",
        "project_id":"123456"
      },
      "gmail":{
        "email":"test@example.com",
        "password":"super_secret"
      },
      "github":{
        "email":"test@example.com",
        "password":"super_secret",
        "repository":"project/repo"
      }
    }

###data.json

This file is used to store the data about your company including company name, names of people, and their email addresses. For example:

    {
      "company":"Example Company",
      "names":[
        "Jason Truluck",
        "Foo Bar"
      ],
      "emails":[
        "test@example.com",
        "test2@example.com"
      ]
    }

Updated: October 12, 2012