## Command for Cloud functions
1. Reset Daily Aurora everyday:    curl -X POST "https://us-central1-aurora-519ef.cloudfunctions.net/resetHasPosted"\-H "Content-Type: application/json" \-d '{"promptText": "Introduce Yourself"}'    
2. Send custom notification to every user: 
curl -X POST https://us-central1-aurora-519ef.cloudfunctions.net/sendCustomNotificationToAllUsers \
-H "Content-Type: application/json" \
-d '{"title": "Aurora", "body": "Daily Aurora posted"}'
