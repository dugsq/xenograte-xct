### Overview ###
This Xenode will execute sql statements set in the `@config` using mapping context from `msg.context` and row values from `msg.data`. Each incoming message with data should be an array with a hash inside for each row. If there was no readable data from the message, the xenode will still run the sql template without inserting values.

The config.yml must contain information about the sql template to choose from and the path to the database. 
