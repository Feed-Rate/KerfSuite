import pytest
from pytest_bdd import scenario, given, when, then, parsers
from core.models import Job, Sheet, Piece
from core.optimizer import optimize
from core.persistence import save_job, load_job, load_zad_file
import tempfile
import os

# Scenarios
@scenario('features/optimization.feature', 'Basic nested optimization')
def test_optimization_basic():
    pass

@scenario('features/optimization.feature', 'Respecting grain direction (rotation lock)')
def test_optimization_grain():
    pass

@scenario('features/persistence.feature', 'Saving and loading a job')
def test_persistence_save_load():
    pass

@scenario('features/persistence.feature', 'Importing legacy Z-CAD files')
def test_persistence_import():
    pass

# Shared Fixtures
@pytest.fixture
def context():
    return {}

# Step Definitions
@given(parsers.parse('a job with a {kerf:d}mm kerf'), target_fixture='job')
def job_with_kerf(kerf):
    return Job(blade_kerf=kerf)

@given(parsers.parse('a stock sheet of {width:d}x{height:d}mm with quantity {qty:d}'))
def add_sheet(job, width, height, qty):
    job.sheets.append(Sheet(width=width, height=height, quantity=qty, active=True))

@given(parsers.parse('{count:d} pieces of {width:d}x{height:d}mm'))
def add_pieces(job, count, width, height):
    job.pieces.append(Piece(width=width, height=height, quantity=count))

@when('I run the optimization')
def run_optimization(job):
    optimize(job)

@then(parsers.parse('all {count:d} pieces should be placed'))
def check_placed_count(job, count):
    assert job.total_pieces_placed == count

@then(parsers.parse('the overall efficiency should be greater than {min_eff:d}%'))
def check_efficiency(job, min_eff):
    assert job.overall_efficiency > min_eff

@given(parsers.parse('a piece of {width:d}x{height:d}mm with rotation locked'))
def add_locked_piece(job, width, height):
    job.pieces.append(Piece(width=width, height=height, quantity=1, can_rotate=False))

@then('the piece should be unplaced')
def check_unplaced(job):
    assert len(job.unplaced) == 1

@when('I unlock rotation')
def unlock_rotation(job):
    for p in job.pieces:
        p.can_rotate = True

@when('I run the optimization again')
def run_optimization_again(job):
    optimize(job)

@then('the piece should be placed')
def check_placed(job):
    assert job.total_pieces_placed == 1
    assert len(job.unplaced) == 0

# Persistence Steps
@given(parsers.parse('a new job named "{name}"'), target_fixture='job')
def new_named_job(name):
    return Job(name=name)

@given(parsers.parse('I add a piece of {width:d}x{height:d}mm'))
def add_single_piece(job, width, height):
    job.pieces.append(Piece(width=width, height=height, quantity=1))

@when(parsers.parse('I save the job to "{filename}"'))
def save_job_step(job, filename, context):
    path = os.path.join(tempfile.gettempdir(), filename)
    save_job(job, path)
    context['last_path'] = path

@when(parsers.parse('I load the job from "{filename}"'))
def load_job_step(context, filename):
    path = context['last_path']
    context['loaded_job'] = load_job(path)

@then(parsers.parse('the job name should be "{name}"'))
def check_loaded_name(context, name):
    assert context['loaded_job'].name == name

@then(parsers.parse('there should be {count:d} piece in the list'))
def check_loaded_piece_count(context, count):
    assert len(context['loaded_job'].pieces) == count

@given('a legacy ZAD file with 20 pieces', target_fixture='zad_path')
def legacy_zad_file():
    content = (
        "Material: \tTest Material\r\n"
        "Mat.\t1\t1\t-1\t4100\t1200\t1\t95\t155\t10\t4\t400\r\n"
        "Auftrag:\tTest Customer\r\n"
        "Pos.\t1\t20\t800\t500\t0\r\n"
    )
    with tempfile.NamedTemporaryFile(suffix=".ZAD", delete=False, mode="wb") as f:
        f.write(content.encode("latin-1"))
        return f.name

@when('I import the ZAD file')
def import_zad_step(context, zad_path):
    context['loaded_job'] = load_zad_file(zad_path)
    os.unlink(zad_path)

@then('the job should contain 20 pieces')
def check_imported_pieces(context):
    assert sum(p.quantity for p in context['loaded_job'].pieces) == 20

@then('the blade kerf should be imported correctly')
def check_imported_kerf(context):
    assert context['loaded_job'].blade_kerf == 4
