# Deployment Automation

There was a time when I was in a shop that did all software deploys manually.  There were a lot of applications and a lot of steps that had to be performed manually.  Needless to say, human error reared its head on almost every single deploy.  I decided to put an end to the madness by writing scripts that handled the process, making it repeatable and documenting what we actually did for each deploy.  We eventually were able to implement octopus to deploy our appplications but these scripts served us well until that was rolled out.

job-deploy.ps1
---------------
This script handles deploying mission critical console applications (jobs) that are run from Windows Task Scheduler.  Jobs were run 24/7 on various schedules so we had to be careful about deploying binaries or ending tasks when a particular job was running.  This script will end a task or wait for it to complete, disable the task, copy the new binaries, and then ren-enable the task.

