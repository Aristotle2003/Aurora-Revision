## Command for Cloud functions
1. Reset hasposted to false for all users: curl -X POST https://us-central1-aurora-519ef.cloudfunctions.net/resetHasPosted
2. Send custom notification to every user: 
curl -X POST https://us-central1-aurora-519ef.cloudfunctions.net/sendCustomNotificationToAllUsers \
-H "Content-Type: application/json" \
-d '{"title": "Aurora", "body": "Daily Aurora posted"}'
