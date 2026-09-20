"""Differential tests against the pinned upstream, using the real Lua 5.1 DLL.

Run: python -m unittest discover -s tests -p test_calendar.py -v
The reference reads upstream Solar/Yun; it never reads the generated Lua data.
"""
from datetime import datetime, timedelta
from pathlib import Path
from random import Random
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'mod' / 'TenYearsNineGrid'
VENDOR = ROOT / 'vendor'
sys.path.insert(0, str(VENDOR))
from lunar_python import Solar
from lunar_python.util import LunarUtil
from calendar_lua_bridge import LuaCalendar


def dt(solar):
    return datetime.fromisoformat(solar.toYmdHms())


def iso(solar):
    return dt(solar).isoformat(timespec='seconds') + '+08:00'


def age(birth, boundary):
    b = dt(boundary)
    return b.year - birth.year - int((b.month, b.day, b.hour, b.minute, b.second) <
                                   (birth.month, birth.day, birth.hour, birth.minute, birth.second))


def reference(date, time, gender):
    birth = datetime.fromisoformat(date + 'T' + time)
    solar = Solar.fromYmdHms(birth.year, birth.month, birth.day, birth.hour, birth.minute, birth.second)
    eight = solar.getLunar().getEightChar()
    eight.setSect(2)
    yun = eight.getYun(gender, 2)
    first = yun.getStartSolar()
    result = dict(chart=[eight.getYear(), eight.getMonth(), eight.getDay(), eight.getTime()],
                  selected_decade=1, calendar=dict(library='lunar-python1.4.8', day_sect=2, yun_sect=2,
                  calculation_timezone='UTC+08:00', calculation_utc_offset='+08:00', gender=gender,
                  forward=yun.isForward(), start_date=iso(first), age_convention='completed_years',
                  year_sampling='anniversary_midpoint'), decades=[])
    for decade in yun.getDaYun(9)[1:]:
        index = decade.getIndex()
        start, end = first.nextYear((index - 1) * 10), first.nextYear(index * 10)
        years = []
        for offset in range(10):
            midpoint = start.nextMonth(offset * 12 + 6)
            gz = midpoint.getLunar().getYearInGanZhiExact()
            element = '木火土金水'['甲乙丙丁戊己庚辛壬癸'.index(gz[0]) // 2]
            years.append(dict(year=midpoint.getYear(), gan_zhi=gz, element=element))
        result['decades'].append(dict(index=index, gan_zhi=decade.getGanZhi(), start_date=iso(start),
                                     end_date=iso(end), start_age=age(birth, start), end_age=age(birth, end), years=years))
    return result


class ModulePresenceTests(unittest.TestCase):
    def test_pure_lua_runtime_exists(self):
        self.assertTrue((MOD / 'calendar.lua').is_file(), 'Missing pure-Lua calendar.lua runtime')
        self.assertTrue((MOD / 'calendar_data.lua').is_file(), 'Missing generated calendar_data.lua')


class CalendarTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not all((MOD / name).is_file() for name in ('calendar.lua', 'calendar_data.lua')):
            raise unittest.SkipTest('Runtime not implemented; see ModulePresenceTests failure')
        cls.runtime = LuaCalendar(MOD)

    @classmethod
    def tearDownClass(cls):
        cls.runtime.close()

    def test_01_upstream_documented_examples(self):
        actual = self.runtime.calculate('2005-12-23', '08:37', 1)
        self.assertEqual(actual['chart'], ['乙酉', '戊子', '辛巳', '壬辰'])
        for date, time, gender, start_date in [('2022-03-09', '20:51', 1, '2030-12-12'),
                                               ('2018-06-11', '09:30', 0, '2020-03-21')]:
            with self.subTest(date=date):
                actual = self.runtime.calculate(date, time, gender)
                self.assertEqual(actual['calendar']['start_date'][:10], start_date)
                self.assertEqual(actual, reference(date, time, gender))

    def test_02_full_profiles_1901_to_2026_both_genders(self):
        rng = Random(9021901)
        fixtures = []
        for year in range(1901, 2027):
            date = datetime(year, 1, 1) + timedelta(days=rng.randrange(365))
            fixtures.append((date.strftime('%Y-%m-%d'), f'{rng.randrange(24):02}:{rng.randrange(60):02}'))
        fixtures += [('1901-01-01', '00:00'), ('2000-02-29', '23:00'), ('2004-02-29', '00:00'),
                     ('2005-12-23', '22:59'), ('2005-12-23', '23:00'), ('2005-12-24', '00:00'),
                     ('2026-12-31', '23:59'), ('2099-12-31', '23:59')]
        for index, (date, time) in enumerate(fixtures):
            for gender in (0, 1):
                with self.subTest(date=date, time=time, gender=gender):
                    self.assertEqual(self.runtime.calculate(date, time, gender), reference(date, time, gender))
            if (index + 1) % 25 == 0:
                print(f'  differential: {index + 1} dates, both genders', flush=True)

    def test_03_exact_jie_boundaries_and_source_inclusivity(self):
        # Small seconds-capable pillars helper verifies transitions impossible to
        # express in minute-only birth UI; public calculate still rejects seconds.
        for year in (1901, 2000, 2024, 2099):
            source = Solar.fromYmd(year, 7, 1).getLunar()
            terms = [source.getJieQiTable()[key] for key in source.JIE_QI_IN_USE[::2]
                     if source.getJieQiTable()[key].getYear() == year]
            self.assertEqual(len(terms), 12)
            for term in terms:
                t = dt(term)
                for offset in (-1, 0, 1):
                    instant = t + timedelta(seconds=offset)
                    source_lunar = Solar.fromYmdHms(instant.year, instant.month, instant.day,
                                                    instant.hour, instant.minute, instant.second).getLunar()
                    eight = source_lunar.getEightChar()
                    eight.setSect(2)
                    actual = self.runtime.execute('return C.pillars(' + ','.join(str(v) for v in
                        (instant.year, instant.month, instant.day, instant.hour, instant.minute, instant.second)) + ')', 1)[0]
                    self.assertEqual(actual, [eight.getYear(), eight.getMonth(), eight.getDay(), eight.getTime()])
                self.assertEqual(dt(term.getLunar().getPrevJie().getSolar()), t)
                self.assertGreater(dt(term.getLunar().getNextJie().getSolar()), t)
                # Minute on either side also checks Yun's separate seconds truncation.
                for instant in (t.replace(second=0), t.replace(second=0) + timedelta(minutes=1)):
                    for gender in (0, 1):
                        date, time = instant.strftime('%Y-%m-%d'), instant.strftime('%H:%M')
                        self.assertEqual(self.runtime.calculate(date, time, gender), reference(date, time, gender))

    def test_04_reject_invalid_inputs(self):
        for expression in ('nil', '{}', '{date="2000-02-30",time="08:00",gender=1}',
                           '{date="1900-01-01",time="08:00",gender=1}',
                           '{date="2100-01-01",time="08:00",gender=1}',
                           '{date="2024-02-29",time="24:00",gender=1}',
                           '{date="2024-02-29",time="23:60",gender=1}',
                           '{date="2024-02-29",time="08:00:01",gender=1}',
                           '{date="2024-02-29",time="08:00",gender=2}',
                           '{date="2024-02-29",time="08:00",gender=true}',
                           '{date="2024-2-29",time="08:00",gender=0}'):
            with self.subTest(expression=expression):
                profile, error = self.runtime.execute('return C.calculate(' + expression + ')', 2)
                self.assertIsNone(profile)
                self.assertIsInstance(error, str)
                self.assertTrue(any(ord(char) > 127 for char in error))

    def test_05_runtime_does_not_require_io_or_os(self):
        # Loaded data and runtime operate with external side-effect APIs absent.
        self.runtime.execute('io=nil; os=nil; require=nil; love=nil; SMODS=nil')
        self.assertEqual(self.runtime.calculate('2005-12-23', '08:37', 1), reference('2005-12-23', '08:37', 1))
        self.assertLess((MOD / 'calendar_data.lua').stat().st_size, 200_000)

    def test_06_leap_start_anniversaries_anchor_to_first_start(self):
        # Upstream-only search identified this synthetic fixture: first start is
        # leap day 2008; +10 years clamps, +20 years recovers Feb 29 from the anchor.
        actual = self.runtime.calculate('1999-02-02', '08:37', 0)
        self.assertEqual(actual, reference('1999-02-02', '08:37', 0))
        self.assertEqual(actual['calendar']['start_date'], '2008-02-29T00:37:00+08:00')
        self.assertEqual(actual['decades'][1]['start_date'], '2018-02-28T00:37:00+08:00')
        self.assertEqual(actual['decades'][2]['start_date'], '2028-02-29T00:37:00+08:00')

    def test_07_exact_minute_jie_yun_next_is_exclusive(self):
        # These upstream Jie have second=00, so public HH:MM input can represent
        # equality exactly (including LiChun's simultaneous year/month change).
        for stamp in ('1908-07-07T21:48:00', '1948-02-05T05:42:00'):
            center = datetime.fromisoformat(stamp)
            term = Solar.fromYmdHms(center.year, center.month, center.day,
                                    center.hour, center.minute, 0)
            self.assertEqual(dt(term.getLunar().getPrevJie().getSolar()), center)
            self.assertGreater(dt(term.getLunar().getNextJie().getSolar()), center)
            for minute in (-1, 0, 1):
                instant = center + timedelta(minutes=minute)
                for gender in (0, 1):
                    date, time = instant.strftime('%Y-%m-%d'), instant.strftime('%H:%M')
                    actual = self.runtime.calculate(date, time, gender)
                    self.assertEqual(actual, reference(date, time, gender))
                    if minute == 0:
                        if actual['calendar']['forward']:
                            self.assertGreater(actual['calendar']['start_date'], stamp + '+08:00')
                        else:
                            self.assertEqual(actual['calendar']['start_date'], stamp + '+08:00')


if __name__ == '__main__':
    unittest.main(verbosity=2)
