#Create a new event orchestration https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration
resource "pagerduty_event_orchestration" "my_new_event_orchestration" {
  name = "New Event Data Pipeline"
}

output "event_orchestration_id" {
  description = "value of event_orchestration_routing_keys(s)"
  value       = pagerduty_event_orchestration.my_new_event_orchestration.integration[0].parameters
  
}

#Add a new integration/routing key to the event orchestration https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_integration
resource "pagerduty_event_orchestration_integration" "my_new_integration" {
  event_orchestration = pagerduty_event_orchestration.my_new_event_orchestration.id
  label = "Example integration"
}

data "pagerduty_priority" "p1" {
  name = "P1"
}

#Add a new global set to the event orchestration https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_global
resource "pagerduty_event_orchestration_global" "global" {
  event_orchestration = pagerduty_event_orchestration.my_new_event_orchestration.id
  set {
    id = "start"
    rule {
      label = "Always annotate a note to all events"
      actions {
        annotate = "This incident was created by the Database Team via a Global Orchestration"
        # Id of the next set
        route_to = "step-two"
      }
    }
  }
  set {
    id = "step-two"
    rule {
      label = "Drop events that are marked as no-op"
      condition {
        expression = "event.summary matches 'no-op'"
      }
      actions {
        drop_event = true
      }
    }
    rule {
      label = "If there's something wrong on the replica, then mark the alert as a warning"
      condition {
        expression = "event.custom_details.hostname matches part 'replica'"
      }
      actions {
        severity = "warning"
      }
    }
    rule {
      label = "Otherwise, set the incident to P1 and run a diagnostic"
      actions {
        priority = data.pagerduty_priority.p1.id
        automation_action {
          name = "db-diagnostic"
          url = "https://example.com/run-diagnostic"
          auto_send = true
        }
      }
    }
  }
  catch_all {
    actions { }
  }
}

#Get existing technical services
data "pagerduty_service" "database" {
  name = "SN:IT Services"
}

data "pagerduty_service" "www" {
  name = "SN:E-Commerce"
}

#Add a new router to the event orchestration https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_router
resource "pagerduty_event_orchestration_router" "router" {
  event_orchestration = pagerduty_event_orchestration.my_new_event_orchestration.id
  set {
    id = "start"
    rule {
      label = "Events relating to our relational database"
      condition {
        expression = "event.summary matches part 'database'"
      }
      condition {
        expression = "event.source matches regex 'db[0-9]+-server'"
      }
      actions {
        route_to = data.pagerduty_service.database.id
      }
    }
    rule {
      condition {
        expression = "event.summary matches part 'www'"
      }
      actions {
        route_to = data.pagerduty_service.www.id
      }
    }
  }
  catch_all {
    actions {
      route_to = "unrouted"
    }
  }
}

#Add a new service to the event orchestration https://registry.terraform.io/providers/PagerDuty/pagerduty/latest/docs/resources/event_orchestration_service
resource "pagerduty_event_orchestration_service" "www" {
  service = data.pagerduty_service.www.id
  enable_event_orchestration_for_service = true
  set {
    id = "start"
    rule {
      label = "Always apply some consistent event transformations to all events"
      actions {
        variable {
          name = "hostname"
          path = "event.component"
          value = "hostname: (.*)"
          type = "regex"
        }
        extraction {
          # Demonstrating a template-style extraction
          template = "{{variables.hostname}}"
          target = "event.custom_details.hostname"
        }
        extraction {
          # Demonstrating a regex-style extraction
          source = "event.source"
          regex = "www (.*) service"
          target = "event.source"
        }
        # Id of the next set
        route_to = "step-two"
      }
    }
  }
  set {
    id = "step-two"
    rule {
      label = "All critical alerts should be treated as P1 incident"
      condition {
        expression = "event.severity matches 'critical'"
      }
      actions {
        annotate = "Please use our P1 runbook: https://docs.test/p1-runbook"
        priority = data.pagerduty_priority.p1.id
      }
    }
    rule {
      label = "If there's something wrong on the canary let the team know about it in our deployments Slack channel"
      condition {
        expression = "event.custom_details.hostname matches part 'canary'"
      }
      # create webhook action with parameters and headers
      actions {
        automation_action {
          name = "Canary Slack Notification"
          url = "https://our-slack-listerner.test/canary-notification"
          auto_send = true
          parameter {
            key = "channel"
            value = "#my-team-channel"
          }
          parameter {
            key = "message"
            value = "something is wrong with the canary deployment"
          }
          header {
            key = "X-Notification-Source"
            value = "PagerDuty Incident Webhook"
          }
        }
      }
    }
    rule {
      label = "Never bother the on-call for info-level events outside of work hours"
      condition {
        expression = "event.severity matches 'info' and not (now in Mon,Tue,Wed,Thu,Fri 09:00:00 to 17:00:00 America/Los_Angeles)"
      }
      actions {
        suppress = true
      }
    }
  }
  catch_all {
    actions { }
  }
}