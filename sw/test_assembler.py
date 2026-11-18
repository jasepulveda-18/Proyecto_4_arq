#!/usr/bin/env python3
"""Pruebas del assembler contra los ejemplos oficiales del repositorio."""

from pathlib import Path
import unittest

from assembler import AssemblyError, assemble


SW_DIR = Path(__file__).resolve().parent


class ExampleProgramsTest(unittest.TestCase):
    def assert_matches_reference(self, program: str) -> None:
        source = (SW_DIR / f"{program}.s").read_text(encoding="utf-8")
        expected = (SW_DIR / f"{program}.hex").read_text(encoding="ascii").splitlines()
        actual = [f"{word:08x}" for word in assemble(source)]
        self.assertEqual(actual, expected)

    def test_blink(self) -> None:
        self.assert_matches_reference("blink")

    def test_buttons_leds(self) -> None:
        self.assert_matches_reference("buttons_leds")

    def test_7seg(self) -> None:
        self.assert_matches_reference("7seg")

    def test_game(self) -> None:
        self.assert_matches_reference("game")


class ValidationTest(unittest.TestCase):
    def test_rejects_registers_missing_from_rv32e(self) -> None:
        with self.assertRaisesRegex(AssemblyError, "x0 y x15"):
            assemble("addi x16, x0, 1")

    def test_rejects_unknown_instruction(self) -> None:
        with self.assertRaisesRegex(AssemblyError, "no soportada"):
            assemble("inventada x1, x2, x3")

    def test_rejects_unknown_label(self) -> None:
        with self.assertRaisesRegex(AssemblyError, "numero invalido"):
            assemble("beq x1, x2, no_existe")


if __name__ == "__main__":
    unittest.main()


class Proyecto4Instructions(unittest.TestCase):
    def test_lbu_sb_y_shifts(self):
        from assembler import assemble
        # codificaciones verificadas contra el ensamblador RISC-V de referencia
        self.assertEqual(assemble("lbu x11, 1024(x2)"), [0x40014583])
        self.assertEqual(assemble("sb x10, 1024(x2)"), [0x40a10023])
        self.assertEqual(assemble("slli x5, x10, 6"), [0x00651293])
        self.assertEqual(assemble("srli x11, x5, 6"), [0x0062d593])
        self.assertEqual(assemble("srai x11, x5, 8"), [0x4082d593])
