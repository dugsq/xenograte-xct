### Overview ###
This Xenode will read from a gmail address set in `@config` variables `user_name` and `password`. It will look for the first unread message from the email address set in `sender`. It will send a message to its children for each attachment, where the `data` key contains the data from the attachment.

It will check for new mail every 60 seconds unless `@loop_delay` is set higher.
