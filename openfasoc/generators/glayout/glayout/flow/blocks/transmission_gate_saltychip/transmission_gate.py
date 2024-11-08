#from glayout.flow.pdk.gf180_mapped import gf180
from glayout.flow.pdk.sky130_mapped import sky130_mapped_pdk as sky130
from glayout.flow.pdk.mappedpdk import MappedPDK
from glayout.flow.pdk.util.comp_utils import evaluate_bbox
from gdsfactory import Component
from gdsfactory.components import rectangle
from glayout.flow.primitives.fet import pmos
from glayout.flow.primitives.fet import nmos
from glayout.flow.routing.straight_route import straight_route
from glayout.flow.routing.c_route import c_route
from glayout.flow.routing.L_route import L_route
from glayout.flow.routing.smart_route import smart_route
from glayout.flow.placement.two_transistor_interdigitized import two_nfet_interdigitized
from glayout.flow.placement.two_transistor_interdigitized import two_pfet_interdigitized
from glayout.flow.pdk.util.comp_utils import prec_ref_center, movey, evaluate_bbox, align_comp_to_port

# My own cell library
from inv_lib import basic_inv_cell

def naive_tg_cell(pdk: MappedPDK, pmos_width, pmos_length, nmos_width, nmos_length):
	# To prepare all necessary cells to construct a transmission gate, i.e.
	# 1) PMOS
	# 2) NMOS
	# 3) Inverter (to control the gates of above PMOS and NMOS)
	pfet = pmos(pdk=pdk, with_substrate_tap=False, with_dummy=(False, False), width=pmos_width, length=pmos_length)
	nfet = nmos(pdk=pdk, with_substrate_tap=False, with_dummy=(False, False), width=nmos_width, length=nmos_length)
	inv = basic_inv_cell(pdk=pdk, pmos_width=pmos_width, pmos_length=pmos_length, nmos_width=nmos_width, nmos_length=nmos_length, orientation="vertical")
	
	# Placement and adding ports
	top_level = Component(name="TG")
	pfet_ref = prec_ref_center(pfet)
	nfet_ref = prec_ref_center(nfet)
#	inv_ref = prec_ref_center(inv)
	top_level.add(pfet_ref)
	top_level.add(nfet_ref)
#	top_level.add(inv_ref)
	inv_ref = top_level << inv
	top_level.add_ports(pfet_ref.get_ports_list(), prefix="pmos_")
	top_level.add_ports(nfet_ref.get_ports_list(), prefix="nmos_")
	top_level.add_ports(inv_ref.get_ports_list(), prefix="inv_")

	# Placement
	mos_spacing = pdk.util_max_metal_seperation()
	pfet_ref.movey(evaluate_bbox(nfet_ref)[1]+mos_spacing)
	pfet_ref.movex(evaluate_bbox(inv_ref)[0]+mos_spacing) # Placing the TG's PMOS at right side of the inverter
	nfet_ref.movex(evaluate_bbox(inv_ref)[0]+mos_spacing) # Placing the TG's NMOS at right side of the inverter

	# Routing
	top_level << smart_route(pdk, pfet_ref.ports["multiplier_0_source_W"], nfet_ref.ports["multiplier_0_drain_W"]) # "in" of the TG
	top_level << smart_route(pdk, pfet_ref.ports["multiplier_0_drain_E"], nfet_ref.ports["multiplier_0_source_E"]) # "out" of the TG
	top_level << smart_route(pdk, inv_ref.ports["pmos_multiplier_0_drain_W"], pfet_ref.ports["multiplier_0_gate_W"]) # connect inv's output to PMOS's gate
	top_level << straight_route(pdk, inv_ref.ports["nmos_multiplier_0_gate_E"], nfet_ref.ports["multiplier_0_gate_E"])

	# Add pins and text labels for LVS
	pins_labels_info = list() # list that contains all port and component information
	
    # To define the layers
	gds_met1 = pdk.get_glayer("met2")[0]
	gds_met2 = gds_met1+1
	gds_met3 = gds_met2+1
	gds_met4 = gds_met3+1
	gds_met5 = gds_met4+1
	# To get the respective layers of the underlying TG's PMOS.source port PMOS.drain port
	tg_din_portLayer = top_level.ports["pmos_multiplier_0_source_W"].layer[0]
	tg_dout_portLayer = top_level.ports["pmos_multiplier_0_drain_E"].layer[0]
	# To create the pins w/ labels and append to info list
	tg_din_pin = rectangle(layer=(tg_din_portLayer, 16), size=(1, 1),centered=True).copy() # True set rectangle's centroid to the relative (0, 0)
	tg_dout_pin = rectangle(layer=(tg_dout_portLayer, 16), size=(1, 1), centered=True).copy()
	tg_din_pin.add_label(text="Vin", layer=(tg_din_portLayer, 5))
	tg_dout_pin.add_label(text="Vout", layer=(tg_dout_portLayer, 5))
	pins_labels_info.append((tg_din_pin, top_level.ports["pmos_multiplier_0_source_W"], None))
	pins_labels_info.append((tg_dout_pin, top_level.ports["pmos_multiplier_0_drain_E"], None))

	#print(top_level.ports["pmos_multiplier_0_source_W"].name)
	#top_level.pprint_ports()

	# Move everythin to position
	for comp, prt, alignment in pins_labels_info:
		alignment = ('c', 'b') if alignment is None else alignment
		compref = align_comp_to_port(comp, prt, alignment=alignment)
		#top_level.add(compref)

	return top_level #top_level.flatten()
