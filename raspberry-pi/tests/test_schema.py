"""تعریف مرکزی و اعتبارسنجی فرمان، بدون تغییر دستگاه واقعی."""
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from server import Application, field_type, module_ui, parameter_command, validate_module

def module(**extra):
    data=dict(id='schema-test',name='تست',route='local',request_topic='schema/info',response_topic='schema/result',polling=False)
    data.update(extra)
    return validate_module(data)

class SchemaTests(unittest.TestCase):
    def test_inference_does_not_grant_write(self):
        m=module();ui=module_ui(m,dict(payload=json.dumps(dict(temperature=3.5,IP='192.168.1.11',enabled=True,serial='0012',nested={}))))
        fields={f['key']:f for f in ui['fields']}
        self.assertEqual(fields['IP']['type'],'text');self.assertEqual(fields['temperature']['type'],'number')
        self.assertEqual(fields['enabled']['type'],'boolean');self.assertEqual(fields['serial']['type'],'text')
        self.assertNotIn('nested',fields);self.assertFalse(any(f['editable'] for f in fields.values()))

    def test_fridge_defaults_and_partial_command(self):
        m=module(kind='refrigerator');row=dict(payload='{"Temp":9,"Hyster":1,"TempIn":8.5}')
        ui=module_ui(m,row);self.assertEqual({f['key'] for f in ui['fields'] if f['editable']},{'Temp','Hyster'})
        command=parameter_command(m,row,dict(confirm=True,schema_revision=ui['revision'],values={'Temp':8}))
        self.assertEqual(command,dict(type='Param',Temp=8,Hyster=1))

    def test_schema_version_and_hidden_fields(self):
        m=module(fields=[dict(key='x',label='نمونه',visible=False,editable=True,type='integer',min=0,max=10)])
        row=dict(payload='{"x":2}');ui=module_ui(m,row)
        self.assertFalse(ui['fields'][0]['visible'])
        for data in [dict(confirm=True,values={'x':3}),dict(confirm=True,schema_revision='stale',values={'x':3}),
                     dict(confirm=False,schema_revision=ui['revision'],values={'x':3})]:
            with self.assertRaises(ValueError):parameter_command(m,row,data)

    def test_reject_invalid_types_bounds_and_extra_keys(self):
        m=module(fields=[dict(key='x',label='عدد',type='integer',editable=True,min=0,max=10)])
        row=dict(payload='{"x":2}');revision=module_ui(m,row)['revision']
        for values in [{'x':11},{'x':True},{'x':2.5},{'x':'3'},{'x':float('nan')},{'unknown':2}]:
            with self.assertRaises(ValueError):parameter_command(m,row,dict(confirm=True,schema_revision=revision,values=values))

    def test_text_and_boolean(self):
        m=module(fields=[dict(key='name',label='نام',type='text',editable=True),dict(key='power',label='روشن',type='boolean',editable=True)])
        ui=module_ui(m,None)
        command=parameter_command(m,None,dict(confirm=True,schema_revision=ui['revision'],values={'name':'اتاق','power':False}))
        self.assertEqual(command,dict(type='Param',name='اتاق',power=False))

    def test_invalid_definitions(self):
        for fields in [[dict(key='a/b',label='x')],[dict(key='x',label='x',type='html')],
                       [dict(key='x',label='x',min=5,max=1)],[dict(key='x',label='x'),dict(key='x',label='y')]]:
            with self.assertRaises(ValueError):module(fields=fields)

class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory();self.app=Application(self.folder.name,'test-only','test-only')
        self.app.store.delete_module('refrigerator')
        self.module=self.app.store.save_module(module(kind='refrigerator',share='off'))
        self.app.store.receive(self.module,'local','schema/result','{"type":"Info","Temp":9,"Hyster":1,"TempIn":8.5}')
        self.c=self.app.collector;self.c.states['local']['connected']=True;self.sent=[]
        self.c.publish=lambda *args:self.sent.append(args)
        self.root='homa/'+self.app.store.setting('installation')
    def tearDown(self):self.app.store.db.close();self.folder.cleanup()
    def send(self,route,topic,data,retained=False):
        self.c.on_message(route,SimpleNamespace(topic=topic,payload=json.dumps(data).encode(),retain=retained))
    def test_external_catalog_hides_unshared_modules_and_controls(self):
        self.assertEqual(len(self.c.catalog()['modules']),1)
        self.assertEqual(self.c.catalog('external')['modules'],[])
        self.assertFalse(self.c.catalog('external')['settings_allowed'])
    def test_catalog_is_read_only(self):
        self.send('local',self.root+'/catalog/request',{'type':'Info'})
        self.assertEqual(self.sent[0][2],self.root+'/catalog/state');self.assertEqual(len(self.c.jobs),0)
    def test_legacy_save_preserves_central_layout(self):
        current=self.app.store.save_module(dict(self.module,columns=1,fields=[dict(key='Temp',label='دما',type='number',visible=True,editable=True)]))
        self.app.store.save_module(dict(id=current['id'],name='نام جدید'))
        saved=self.app.store.modules()[0]
        self.assertEqual(saved['columns'],1);self.assertEqual(saved['fields'][0]['label'],'دما')
    def test_control_requires_local_non_retained_and_matching_schema(self):
        data=dict(client_id='testclient123',request_id='request123',confirm=True,values={'Temp':8},schema_revision=module_ui(self.module,self.app.store.latest(self.module['id']))['revision'])
        topic=self.root+'/modules/schema-test/settings'
        self.send('external',topic,data);self.send('local',topic,data,True)
        self.assertEqual(len(self.c.jobs),0)
        self.send('local',topic,data)
        self.assertEqual(len(self.c.jobs),1);self.assertEqual(self.c.jobs[0][1],dict(type='Param',Temp=8,Hyster=1))
        self.assertFalse(json.loads(self.sent[-1][3])['device_acknowledged'])

if __name__=='__main__':unittest.main()
