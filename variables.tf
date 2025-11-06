variable "application_tags" {
    description = "a map of application tags"
    type        = map(string)
    default     = {
        "environment" = "prod"
        "region" = "eastus"
        "createdBy" = "diesl_devops"
        "platform" = "azure"
        "environment" = ""
        "environment" = ""
        "environment" = ""
        "environment" = ""
    }
}

variable "environment_tags" {
    description = "A map of environment tags"
    type        = map(string)
    default     = {
        "environment" = "prod"
        "platform" = "azure"
        "createdBy" = "diesl_devops"
    }
}
