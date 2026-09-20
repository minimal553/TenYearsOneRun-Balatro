"""Real Lua 5.1 observer contract; no window, process or user-save access."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from calendar_lua_bridge import LuaCalendar


class QuitObserverTests(unittest.TestCase):
    def setUp(self):
        self.runtime = LuaCalendar(ROOT / 'mod/TenYearsNineGrid')
        self.runtime.execute((ROOT / 'tools/runtime_qa/qa_mod/quit_observer.lua').read_text(encoding='utf-8'))
        self.runtime.execute('''
qa={status='running'};reports=0;called=0;observed={}
function note(name,data)observed={name=name,data=data}end
function report()reports=reports+1 end
''')

    def tearDown(self):
        self.runtime.close()

    def test_early_quit_records_failure_and_preserves_returns(self):
        self.runtime.execute('''
love={quit=function(reason)called=called+1;assert(reason=='test');return false,'sentinel' end}
TYG_QA_INSTALL_QUIT_OBSERVER(qa,note,report)
local veto,extra=love.quit('test')
assert(veto==false and extra=='sentinel'and called==1)
assert(qa.status=='failed'and qa.error and reports==1)
assert(observed.name=='quit_observed'and observed.data.status_before=='running')
assert(not observed.data.cancelled and #observed.data.trace>0)
''')

    def test_native_cancelled_quit_remains_running(self):
        self.runtime.execute('''
love={quit=function()called=called+1;return true end}
TYG_QA_INSTALL_QUIT_OBSERVER(qa,note,report)
assert(love.quit()==true and called==1)
assert(qa.status=='running'and reports==1 and observed.data.cancelled)
''')

    def test_completed_quit_does_not_change_pass(self):
        self.runtime.execute('''
qa.status='passed';love={quit=function()called=called+1 end}
TYG_QA_INSTALL_QUIT_OBSERVER(qa,note,report)
assert(love.quit()==nil and called==1)
assert(qa.status=='passed'and reports==1 and observed.data.status_before=='passed')
''')

    def test_missing_original_is_not_replaced_with_a_veto(self):
        self.runtime.execute('''
love={};TYG_QA_INSTALL_QUIT_OBSERVER(qa,note,report)
assert(love.quit()==nil and qa.status=='failed'and reports==1)
''')


if __name__ == '__main__':
    unittest.main()
