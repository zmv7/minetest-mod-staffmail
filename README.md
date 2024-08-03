# StaffMail  
### Discord relay setup
* Add `staffmail` to `secure.http_mods` in `minetest.conf`
* Add `staffmail.dcwh_url = <your-webhook-url>` in `minetest.conf`
### Usage
* `/smail` - open staffmail GUI (different for players and for staff)
* `/smail <title> <text>` - send the message directly from the chat
* The delay between messages is 10 minutes (no delay for staff)
* `staffmail` privilege provides access to staffmail control GUI.
