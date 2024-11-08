#from glayout.flow.pdk.gf180_mapped import gf180
from glayout.flow.pdk.sky130_mapped import sky130_mapped_pdk as sky130
from glayout.flow.pdk.mappedpdk import MappedPDK
from glayout.flow.pdk.util.comp_utils import prec_ref_center, movex, movey, evaluate_bbox, align_comp_to_port
from gdsfactory import Component
from gdsfactory.components import rectangle
from glayout.flow.primitives.fet import pmos
from glayout.flow.primitives.fet import nmos
from glayout.flow.routing.straight_route import straight_route
from glayout.flow.routing.c_route import c_route
from glayout.flow.routing.L_route import L_route
from glayout.flow.routing.smart_route import smart_route

def basic_inv_cell(pdk: MappedPDK, pmos_width, pmos_length, nmos_width, nmos_length, orientation):
	# Create a top level component
	top_level = Component("inverter")
	# To prepare one PMOS and one NMOS for the subsequent inverter cell construction
	pfet = pmos(pdk=pdk, with_substrate_tap=False, with_dummy=(False, False), width=pmos_width, length=pmos_length)
	nfet = nmos(pdk=pdk, with_substrate_tap=False, with_dummy=(False, False), width=nmos_width, length=nmos_length)
	
	# Instantiation of above PMOS and NMOS under the top level
	pfet_ref = prec_ref_center(pfet)
	nfet_ref = prec_ref_center(nfet)
	top_level.add(pfet_ref)
	top_level.add(nfet_ref)
	
	# To add the ports
	top_level.add_ports(pfet_ref.get_ports_list(), prefix="pmos_")
	top_level.add_ports(nfet_ref.get_ports_list(), prefix="nmos_")

	# Placement (relative move)
	mos_spacing = pdk.util_max_metal_seperation()
	if(orientation=="horizontal"):
		#pfet_ref.drotate(90)
		#nfet_ref.drotate(90)
		pass
	pfet_ref.movey(evaluate_bbox(nfet)[1] + mos_spacing)

	# Routing
	top_level << smart_route(pdk, pfet_ref.ports["multiplier_0_drain_E"], nfet_ref.ports["multiplier_0_drain_E"])
	top_level << smart_route(pdk, pfet_ref.ports["multiplier_0_gate_W"], nfet_ref.ports["multiplier_0_gate_W"])

	return top_level
