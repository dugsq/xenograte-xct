### Overview ###
This Xenode will send mail to recipients set in the `@config` recipients array. Each entry in the array should be a Hash with at least an email key.

The config.yml can contain information about templates to be used by the Xenode. If an inbound message has no configuration information, the Xenode expects that a default template has been defined.
