"""Exhaust supported date/hour representatives plus every Jie-minute boundary.

This checks matcher totality, not empirical accuracy of traditional fortune claims.
Midnight and late-Zi use different day/hour conventions, so23:00 is additional.
"""
from datetime import datetime, timedelta
from pathlib import Path
import unittest
from calendar_lua_bridge import LuaCalendar, quote

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'mod' / 'TenYearsNineGrid'


class ExhaustiveCoverage(unittest.TestCase):
    def test_all_supported_dates_and_hour_states(self):
        runtime = LuaCalendar(MOD)
        try:
            runtime.execute('M=assert(loadstring(' + quote((MOD/'chart_patterns.lua').read_text(encoding='utf-8')) + '))()')
            runtime.execute('D=assert(loadstring(' + quote((MOD/'calendar_data.lua').read_text(encoding='utf-8')) + '))()')
            stats = runtime.execute('''
              FULL={count=0,counts={},days=0}
              local function inspect(y,m,d,h,mi)
                local chart,err=C.pillars(y,m,d,h,mi or 0,0);assert(chart,err)
                local p,e=M.classify(chart);assert(p,e)
                assert(M.by_key[p.key]and #p.reasons>0,'missing registered/evidenced pattern')
                FULL.count=FULL.count+1;FULL.counts[p.key]=(FULL.counts[p.key]or 0)+1
              end
              INSPECT_ALL=inspect
              for y=1901,2099 do
                local leap=y%4==0 and(y%100~=0 or y%400==0)
                local months={31,leap and 29 or 28,31,30,31,30,31,31,30,31,30,31}
                for m,days in ipairs(months)do for d=1,days do
                  FULL.days=FULL.days+1
                  for h=0,22,2 do inspect(y,m,d,h,0)end
                  inspect(y,m,d,23,0)
                end end
                if y%20==0 then print('EXHAUSTIVE_YEAR '..y..' points='..FULL.count)end
              end
              return FULL
            ''', 1)[0]
            self.assertEqual(stats['days'], (datetime(2100,1,1)-datetime(1901,1,1)).days)
            self.assertEqual(stats['count'], stats['days']*13)
            self.assertEqual(len(stats['counts']), 26)
            terms=runtime.execute('return D.terms',1)[0]
            points=set()
            for row in terms:
                instant=datetime(1900,1,1)+timedelta(seconds=row[0])
                minute=instant.replace(second=0)
                for offset in (-1,0,1):
                    point=minute+timedelta(minutes=offset)
                    if 1901<=point.year<=2099:
                        points.add((point.year,point.month,point.day,point.hour,point.minute))
            statements=['INSPECT_ALL('+','.join(map(str,p))+')'for p in sorted(points)]
            runtime.execute('\n'.join(statements))
            count=runtime.execute('return FULL.count',1)[0]
            self.assertEqual(count, stats['count']+len(points))
            print('FULL_DATE_HOUR_STATES', stats['count'], 'ALL_JIE_MINUTE_BOUNDARIES',len(points),'TOTAL',count,flush=True)
        finally:
            runtime.close()


if __name__=='__main__':
    unittest.main(verbosity=2)
