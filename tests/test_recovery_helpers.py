"""Test target selection and account guard using a fake CLI, without AWS access."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TG = 'arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/lab/1234'
FAKE = '''#!/usr/bin/env python3
import json,os,sys
args=sys.argv[1:]
with open(os.environ['CLI_LOG'],'a') as f: f.write(json.dumps(args)+'\\n')
if args[:2]==['sts','get-caller-identity']: print('123456789012')
elif args[:2]==['ecs','describe-services']:
 print(json.dumps({'failures':[], 'services':[{'loadBalancers':[{'targetGroupArn':os.environ['TARGET_GROUP'], 'containerName':'wordpress','containerPort':80}]}]}))
elif args[:2]==['elbv2','describe-target-groups']: print('ip')
elif args[:2]==['ecs','list-tasks']: print(json.dumps({'taskArns':['task-good','task-unrelated']}))
elif args[:2]==['ecs','describe-tasks']:
 good=args[args.index('--tasks')+1]=='task-good'
 print(json.dumps({'tasks':[{'lastStatus':'RUNNING','group':'service:lab' if good else 'service:unrelated','containers':[{'name':'wordpress','networkInterfaces':[{'privateIpv4Address':'10.0.0.10' if good else '10.0.0.99'}]}]}]}))
elif args[:2] in [['elbv2','register-targets'],['elbv2','wait']]: pass
else: sys.exit('Unexpected call '+str(args))
'''

class RecoveryTests(unittest.TestCase):
    def run_helper(self, account):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            fake = p / 'aws'
            fake.write_text(FAKE)
            fake.chmod(0o755)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ['PATH'],
                       CLI_LOG=str(p/'calls.jsonl'), TARGET_GROUP=TG)
            result = subprocess.run(['bash',str(ROOT/'scripts/recover-ecs-targets.sh'),
                                     'us-east-1','cluster','lab',TG,account],
                                    env=env, capture_output=True,text=True)
            calls = [json.loads(line) for line in (p/'calls.jsonl').read_text().splitlines()]
            return result,calls

    def test_wrong_account_never_mutates(self):
        result,calls = self.run_helper('999999999999')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(len(calls),1)
        self.assertEqual(calls[0][:2],['sts','get-caller-identity'])

    def test_registers_only_matching_service(self):
        result,calls = self.run_helper('123456789012')
        self.assertEqual(result.returncode,0,result.stderr)
        registrations = [c for c in calls if c[:2]==['elbv2','register-targets']]
        self.assertEqual(len(registrations),1)
        self.assertIn('Id=10.0.0.10,Port=80',registrations[0])
        self.assertNotIn('10.0.0.99',json.dumps(registrations))

if __name__ == '__main__':
    unittest.main()
