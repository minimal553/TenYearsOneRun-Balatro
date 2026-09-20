"""Finite coverage and actual calendar sampling in the installed Lua 5.1 DLL.

Run: python -m unittest discover -s tests -p test_pattern_coverage.py -v
The 60 x 60 grid combines independently valid pillars; it is NOT an assertion
that every such year/month/day/hour combination occurs on the real calendar.
The second cohort uses the existing verified calendar adapter, 1901--2099.
"""
import json
import unittest
from pathlib import Path

from calendar_lua_bridge import LuaCalendar, quote

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'mod' / 'TenYearsNineGrid'
IDS = ('zhengguan qisha zhengcai piancai zhengyin pianyin shishen shangguan '
       'jianlu yuejie yangren cong_cai cong_sha cong_er cong_shi quzhi yanshang '
       'jiase congge runxia hua_tu hua_jin hua_shui hua_mu hua_huo changgui').split()


class PatternCoverage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runtime = LuaCalendar(MOD)
        for variable, filename in [('M', 'chart_patterns.lua'), ('R', 'rules.lua')]:
            cls.runtime.execute(variable + '=assert(loadstring(' + quote(
                (MOD / filename).read_text(encoding='utf-8')) + '))()')
        cls.runtime.execute('MATCH=assert(loadstring(' + quote(
            (MOD / 'pattern_matcher.lua').read_text(encoding='utf-8')) + '))()(R,M)')
        cls.runtime.execute('''
          function new_stats()
            local s={count=0,distribution={},first={},tiers={},combos={},statuses={}}
            for _,p in ipairs(M.catalog)do s.distribution[p.key]=0;s.tiers[p.key]={0,0,0} end
            return s
          end
          function inspect(s,chart,label)
            local p,e=M.classify(chart);assert(p,e)
            assert(M.by_key[p.key] and p.name==M.by_key[p.key].name,'unknown category')
            assert(p.natal_tier>=1 and p.natal_tier<=3 and p.natal_tier%1==0,'tier')
            assert(#p.reasons>0 and p.features.total_weight==80,'evidence')
            local total,visible=0,0
            for _,w in pairs(p.features.gods)do total=total+w end
            for _,n in pairs(p.features.visible)do visible=visible+n end
            assert(total==80 and visible==3,'day stem leaked or hidden stem omitted')
            if p.kind=='following' or p.kind=='dominant' or p.kind=='transform' then
              assert(p.features.special_checks[p.key].passed,'unqualified special')
            end
            if p.combo then
              assert(p.combo.key and p.combo[1]==nil and #p.combo.trace>=3,'stacked or opaque combo')
              s.combos[p.combo.key]=(s.combos[p.combo.key]or 0)+1
            end
            s.count=s.count+1;s.distribution[p.key]=s.distribution[p.key]+1
            s.tiers[p.key][p.natal_tier]=s.tiers[p.key][p.natal_tier]+1
            s.statuses[p.status]=(s.statuses[p.status]or 0)+1
            if not s.first[p.key] then s.first[p.key]={label=label,chart=chart} end
            return p
          end
        ''')

    @classmethod
    def tearDownClass(cls):
        cls.runtime.close()

    def test_01_finite_60_day_by_60_month_grid(self):
        [stats] = self.runtime.execute('''
          local stems={'甲','乙','丙','丁','戊','己','庚','辛','壬','癸'}
          local branches={'子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'}
          local function pillar(n)return stems[n%10+1]..branches[n%12+1] end
          local stats=new_stats()
          for day=0,59 do for month=0,59 do
            local chart={pillar((day*7+month*11)%60),pillar(month),pillar(day),pillar((day*13+month*17)%60)}
            local p=inspect(stats,chart,string.format('synthetic-day-%d-month-%d',day,month))
            local q=assert(M.classify(chart))
            assert(q.key==p.key and q.natal_tier==p.natal_tier and
             (q.combo and q.combo.key or '')==(p.combo and p.combo.key or ''),'not deterministic')
          end end
          return stats
        ''', 1)
        self.assertEqual(stats['count'], 3600)
        self.assertEqual(sum(stats['distribution'].values()), 3600)
        self.assertEqual(set(stats['distribution']), set(IDS))
        print('SYNTHETIC_60x60 ' + json.dumps(stats['distribution'], sort_keys=True))

    def test_02_actual_calendar_1901_2099(self):
        [stats] = self.runtime.execute('''
          local stats=new_stats()
          stats.through_2026={count=0,distribution={}}
          for _,p in ipairs(M.catalog)do stats.through_2026.distribution[p.key]=0 end
          for year=1901,2099 do for month=1,12 do
            for _,day in ipairs({1,8,15,22})do for hour=0,22,2 do
              local chart,e=C.pillars(year,month,day,hour,0,0);assert(chart,e)
              local p=inspect(stats,chart,string.format('%04d-%02d-%02d %02d:00 UTC+08:00',year,month,day,hour))
              if year<=2026 then
                local past=stats.through_2026;past.count=past.count+1;past.distribution[p.key]=past.distribution[p.key]+1
              end
            end end
          end end
          return stats
        ''', 1)
        self.assertEqual(stats['count'], 199 * 12 * 4 * 12)
        self.assertEqual(sum(stats['distribution'].values()), stats['count'])
        self.assertEqual(set(stats['first']), set(IDS), 'actual-date reachability must be demonstrated for every category')
        print('ACTUAL_CALENDAR_COUNT ' + str(stats['count']))
        print('ACTUAL_CALENDAR_DISTRIBUTION ' + json.dumps(stats['distribution'], sort_keys=True))
        print('ACTUAL_CALENDAR_FIRST ' + json.dumps(stats['first'], ensure_ascii=True, sort_keys=True))
        print('ACTUAL_CALENDAR_TIERS ' + json.dumps(stats['tiers'], sort_keys=True))
        print('ACTUAL_COMPOSITES ' + json.dumps(stats['combos'], sort_keys=True))
        print('THROUGH_2026 ' + json.dumps(stats['through_2026'], sort_keys=True))
        self.assertEqual(stats['through_2026']['count'], 126 * 12 * 4 * 12)
        self.assertEqual(len(stats['combos']), 12, 'all composites need real calendar witnesses')
        self.assertTrue(all(n > 0 for n in stats['tiers']['qisha']), '七杀 must not be hardcoded to one game tier')
        self.assertTrue(all(n > 0 for n in stats['tiers']['hua_mu']), 'special name must not determine a game tier')

    def test_03_complete_profiles_and_legacy_independence(self):
        [count] = self.runtime.execute('''
          R.match_calendar=function()error('legacy five-template route must never be called')end
          local count=0
          for _,date in ipairs({'1901-01-01','1950-06-15','2000-02-29','2005-12-23','2026-09-20','2099-12-31'})do
            for _,time in ipairs({'00:00','12:30','22:59','23:00','23:59'})do for gender=0,1 do
              local raw,e=C.calculate({date=date,time=time,gender=gender});assert(raw,e)
              local p,err=MATCH(raw);assert(p,err);assert(R.validate_profile(p))
              assert(#p.decades==8 and p.pattern.key==p.route.key and p.pattern.natal_tier==p.natal_tier)
              assert(raw.pattern==nil and raw.decades[1].luck_tier==nil,'mutated raw')
              for _,d in ipairs(p.decades)do
                assert(d.affinity>=-1 and d.affinity<=1 and d.affinity_version==M.version)
                assert(d.grid.target_multiplier==R.grid(p.natal_tier,d.luck_tier).target_multiplier)
              end
              count=count+1
            end end
          end
          return count
        ''', 1)
        self.assertEqual(count, 60)

    def test_04_frozen_real_dates_and_cross_pillar_constraints(self):
        fixtures = json.loads((ROOT / 'tests' / 'pattern_calendar_fixtures.json').read_text(encoding='utf-8'))
        stems = '甲乙丙丁戊己庚辛壬癸'
        branches = '子丑寅卯辰巳午未申酉戌亥'
        self.assertEqual([f['key'] for f in fixtures['fixtures']], IDS)
        for fixture in fixtures['fixtures']:
            with self.subTest(key=fixture['key'], date=fixture['date'], time=fixture['time']):
                self.assertLessEqual(int(fixture['date'][:4]), 2026, 'every category has a dated witness through 2026')
                raw = self.runtime.calculate(fixture['date'], fixture['time'], 1)
                self.assertEqual(raw['chart'], fixture['chart'])
                # Independent 五虎遁 / 五鼠遁 relation checks, in addition to the
                # calendar source. These witnesses exclude the 23:00 convention.
                year, month, day, hour = raw['chart']
                month_offset = (branches.index(month[1]) - 2) % 12
                month_stem = ((stems.index(year[0]) % 5) * 2 + 2 + month_offset) % 10
                hour_stem = ((stems.index(day[0]) % 5) * 2 + branches.index(hour[1])) % 10
                self.assertEqual(stems.index(month[0]), month_stem)
                self.assertEqual(stems.index(hour[0]), hour_stem)
                chart = '{' + ','.join(quote(p) for p in raw['chart']) + '}'
                [key] = self.runtime.execute('return assert(M.classify(' + chart + ')).key', 1)
                self.assertEqual(key, fixture['key'])

    def test_05_targeted_past_metal_formation_search(self):
        [stats] = self.runtime.execute('''
          local count,found=0,{}
          for year=1901,2026 do for month=8,10 do for day=1,28 do for _,hour in ipairs({8,20})do
            local chart=assert(C.pillars(year,month,day,hour,0,0))
            local p=assert(M.classify(chart));count=count+1
            if p.key=='congge' then
              found[#found+1]={date=string.format('%04d-%02d-%02d',year,month,day),time=string.format('%02d:00',hour),chart=chart}
            end
          end end end end
          return {count=count,found=found}
        ''', 1)
        self.assertEqual(stats['count'], 21168)
        self.assertEqual([f['date'] for f in stats['found']],
                         ['1968-10-07', '1970-10-07', '1980-10-04', '2018-09-25'])
        print('TARGETED_PAST_CONGGE ' + json.dumps(stats, ensure_ascii=True, sort_keys=True))


if __name__ == '__main__':
    unittest.main(verbosity=2)
