_ = require 'underscore'
m = require './middleware'
# util = require 'util'
request = require 'request'

module.exports = (app) ->
  Team = app.db.model 'Team'
  Deploy = app.db.model 'Deploy'

  (req, res, next) ->
    return next() unless req.method is 'GET' and req._parsedUrl.pathname is '/deploys' 
  
    # custom error handler (since the default one dies w/o session)
    error = (err) ->
      console.error err.toString().red
      res.end JSON.stringify(err)

    teamcode = req.query.teamcode

    Team.findByCode teamcode, (err, team) ->
      return error(err) if err
      return res.send(404) unless team

      console.log "#{'DEPLOY'.magenta} #{team.name} (#{team.id})"

      attr = _.clone req.query
      attr.teamId = team.id
      attr.remoteAddress = req.socket.remoteAddress
      attr.hostname = 'ubuntu'
      attr.os = 'ubuntu'
      attr.remoteAddress = 'joyent'
      attr.platform = 'joyent'

      # If on prod
      teamURL = "#{team.slug}.2013.nodeknockout.com"
      teamURI = "http://#{team.slug}.2013.nodeknockout.com"
      request.get teamURI, (errorRequest, response, body) ->
        if errorRequest
          console.log "THE ERROR IS:"
          console.log errorRequest
          console.log 'the URL: #{teamURL} does not have nothing'
          return res.end "#{team.slug}.2013.nodeknockout.com is not ready"
        else  
          # save the deploy in the db
          deploy = new Deploy attr
          
          deploy.save (err, deploy) ->
            if err 
              console.log 'I want to see the error here'
              return error(err)
            # return error(err) if err

            # increment overall/team deploy count
            $inc = deploys: 1
            app.stats.increment $inc
            team.incrementStats $inc, (err, team) ->
              
              return error(err) if err
              app.events.emit 'updateTeamStats', team
              app.events.emit 'deploy', deploy, team
              console.log "All good, deploy count stored"
              return res.send JSON.stringify deploy


          
      
