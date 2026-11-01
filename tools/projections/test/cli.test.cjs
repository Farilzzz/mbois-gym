const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');

const CLI_PATH = path.resolve(__dirname, '../cli.cjs');

describe('CLI Command Execution', () => {
  it('displays help when --help is passed', () => {
    const output = execFileSync('node', [CLI_PATH, '--help'], { encoding: 'utf8' });
    assert.match(output, /Mbois Gym - Manager Dashboard Projection Builder/i);
    assert.match(output, /--project/);
    assert.match(output, /--apply/);
    assert.match(output, /--dry-run/);
  });

  it('fails with clear error if --project is missing', () => {
    assert.throws(() => {
      execFileSync('node', [CLI_PATH, '--year', '2026'], { encoding: 'utf8', stdio: 'pipe' });
    }, /--project/);
  });

  it('fails with clear error if unauthorized project is passed', () => {
    assert.throws(() => {
      execFileSync('node', [CLI_PATH, '--project', 'other-project'], { encoding: 'utf8', stdio: 'pipe' });
    }, /tidak diizinkan/i);
  });

  it('fails with prohibited options like --password', () => {
    assert.throws(() => {
      execFileSync('node', [CLI_PATH, '--project', 'mbois-gym', '--password', 'secret'], { encoding: 'utf8', stdio: 'pipe' });
    }, /dilarang/i);
  });
});
