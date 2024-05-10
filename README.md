# Adoption Configuration Pipelines

This repository contains the configuration for each application within the Adoption pod. Each application has it's own configuration set.

See the [configuration pipelines documentation](https://govukverify.atlassian.net/wiki/spaces/PLAT/pages/3071705136/How+to+create+a+configuration+pipeline) for more information.

These pipelines are deployed through secure pipelines, any new parameters committed to `main` branch will be deployed to all environments.

## Add a new parameter

To add new parameters to the pipeline an `AWS::SSM::Parameter` resource must be added _and_ a map which represents the values for each environment.

**Note:** Test against ephemeral development parameters in a branch deployment before committing and deploying parameters to production.

### Naming convention

The naming convention for new parameters is `/application/component/setting-name`:

The value given for the component section should relate to the stack being deployed, e.g. `frontend`, `cognito`, `api`. If a setting relates to multiple components within the application then the convention is to call this `config`.

**Note:** An additional environment section will be added for [pseudo-environments such as local and preview](https://govukverify.atlassian.net/wiki/spaces/DFA/pages/3962929695/Build+and+Deployment+processes#Test-and-Local-Builds) stacks `/application/environment/component/setting-name`

### Resource

Under the Resources section:
```
  ExampleSettingParameter:
    Type: AWS::SSM::Parameter
    Properties:
      Name: !Join
        - "/"
        - - !Sub "/${Application}"
          - !If [IsLocal, !Sub "${Environment}-${LocalName}", !Ref AWS::NoValue]
          - "config"
          - "example-setting"
      Type: String
      Value: !FindInMap [ ExampleSetting, Environment, !Ref Environment ]
      Tags:
        "sse:component": "adoption-application-config"
        "sse:environment": !Ref Environment
        "sse:application": !Ref Application
```

**Note:** Each parameter should include the tags specified above, the application will be given attribute-based access to the parameters with these tags.

### Mapping

Under the Mappings section:
```
  ExampleSetting:
    Environment:
      local: "true"
      dev: "true"
      build: "true"
      staging: "true"
      integration: "true"
      production: "false"
```

**Note:** Each mapping _MUST_ contain keys for all the possible values for the Environment input parameter as listed above.
