# There should be a directory called ise with ISE project and files there. Just create a new project in ISE and copy the files here.
# Example:
# Makefile
# main.v
# azpr_evboard.ucf
# ise/
# 	main.xst
# 	main.prj
# 	etc...

# Path to your ISE installation
isePath=/home/domin/drivers/Xilinx/14.7/ISE_DS/ISE/bin/lin64
myPath = $(shell pwd)
constrainsFile = "azpr_evboard.ucf"



VERILOG_SOURCES = \
	main_graphic_mode.v \
	uart_rx.v \
	vga_gen.v \
	vram_24k.v

ISE_PROJECT_FILE = ise/main.prj




all: $(ISE_PROJECT_FILE) build upload


$(ISE_PROJECT_FILE): $(VERILOG_SOURCES)
	@mkdir -p ise
	@rm -f $(ISE_PROJECT_FILE)
	@for file in $(VERILOG_SOURCES); do \
		echo "verilog work \"../$$file\"" >> $(ISE_PROJECT_FILE); \
	done

build:
	(cd ise && $(isePath)/xst -intstyle ise -ifn "$(myPath)/ise/main.xst" -ofn "$(myPath)/ise/main.syr" )
	(cd ise && $(isePath)/ngdbuild -intstyle ise -dd _ngo -nt timestamp -uc ../$(constrainsFile) -p xc3s250e-vq100-4 main.ngc main.ngd  )
	(cd ise && $(isePath)/map -intstyle ise -p xc3s250e-vq100-4 -cm area -ir off -pr off -c 100 -o main_map.ncd main.ngd main.pcf )
	(cd ise && $(isePath)/par -w -intstyle ise -ol high -t 16 main_map.ncd main.ncd main.pcf )
	(cd ise && $(isePath)/trce -intstyle ise -v 3 -s 4 -n 3 -fastpaths -xml main.twx main.ncd -o main.twr main.pcf -ucf ../$(constrainsFile) )
	(cd ise && $(isePath)/bitgen -intstyle ise -f main.ut main.ncd )
	cp ise/main.bit main.bit


# commands below are for https://yone2.net/azpr_evboard/ board

upload:
#	openocd -f /home/domin/Dokumenty/projects/fpga/azpr.cfg -f /usr/share/openocd/scripts/cpld/xilinx-xcf-s.cfg -c "init; pld load 0 /home/domin/Dokumenty/projects/fpga/makeTest/main.bit; shutdown"
	xc3sprog -c amontec -L -p 1 main.bit

flash:
	xc3sprog -c amontec -L -p 0 main.bit
	xc3sprog -c amontec -L -p 0 -R

erase:
	xc3sprog -c amontec -L -p 0 -e


clean:
	rm -rf ise/*.ngc ise/*.ngd ise/*.ncd ise/*.pcf ise/*.xwbt ise/*.txt ise/*.csv ise/*.bgn ise/*.mrp ise/*.bld ise/*.unroutes ise/*.map ise/*.xrpt ise/*.twr ise/*.pad ise/*.lso ise/*.syr ise/*.twx ise/*.log ise/*.html ise/*.xml ise/_ngo ise/_xmsgs ise/*.xrpt ise/*.bit ise/*.ngm ise/*.ngr ise/*.ptwx ise/*.summary.xml ise/*.par ise/*.drc
	rm -f main.bit
	rm -rf ise/xst/work
	rm -rf ise/xlnx_auto_0_xdb

# consider blacklisting ftdi_sio module for the amontec jtagkey and other ft2232 based jtag programmers
# echo "blacklist ftdi_sio" > /etc/modprobe.d/blacklist-ftdi.conf
